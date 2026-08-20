# systemd, Sandboxing, and Capabilities

systemd has won. Unix-philosphy ([whatever that means](./assets/unix_philosophy.png)) folks are mad. Real users are happy.
It turns out that having an init that's designed around actual service lifetimes is actually pretty great.
But for people who prefer the Runit idiom services killing themselves in a loop until their dependencies are
satisfied, they of course can continue using it.

But systemd does a lot, that is true. Much more than many people realize. I don't even necessarily mean the
semi-seperate projects that live in the systemd repo, like systemd-boot, I mean the PID 1 daemon.

## Sandboxing with systemd

I'm not quite sure how widely known this is, but systemd has most of the sandboxing (without using a VM) one would
want built-in. It has built-in support for OCI containers, so you do not need to install Docker or Podman to run
containers via [`systemd-nspawn(5)`](https://man7.org/linux/man-pages/man5/systemd-nspawn.5.html).
This is pretty cool. Just run something like:
```
> importctl -m pull-oci docket.io/library/bash bash
> systemd-nspawn -M bash /usr/lock/bin/bash
```
and it will run.

That is the containerization technology that most people are familiar with. But containers sort of annoy me because
they pretend to be some sort of tough security boundary, when they are really just a bunch of kernel features
mashed together to pretend like something is isolated. They are pretty leaky. An alternative is systemd service hardening.
Service hardening uses the same kernel features (and some more) as containers, and it often integrates more cleanly with
the rest of the system. Rather than using a seperate tool (docker, podman), they are just the same old systemd services
with journald readout.

Lets try to make a "container" with systemd. It is not too hard. Create a unit file:
```ini
[Unit]
Description=Some service

[Service]
Type=simple
ExecStart=/path/to/binary

# Mount ns
PrivateMounts=true

# IPC ns
PrivateIPC=true

# User ns
PrivateUsers=true

# Clock ns
ProtectClock=true

# PID ns
PrivatePIDs=true

# Network ns
PrivateNetwork=true

# control group ns
ProtectControlGroups="strict"

# Hostname ns
ProtectHostname=true

# Bind some directory into the mount namespace
BindPaths=/mnt/files

[Install]
WantedBy=default.target
```
And this is basically equivalent to a container. There are many many more options use can use that can limit the exact system calls a service can use,
restrict the devices used, restrict the exact sockets that can bound (`PrivateNetwork` disables the ability to connect to the host system at all.),
and many more. I have an extensive example [here](https://wiki.nixos.org/wiki/Systemd/Hardening#Hardened_service_unit_example) that talks about more
options in-depth.

One of my favorite ways to harden services is to [`pivot_root(2)`](https://man7.org/linux/man-pages/man2/pivot_root.2.html) to the services runtime directory
under `/run/SomeService`. This isolates the service to a tmpfs that is destroyed when the service stops.
This is done with a combination of [`RuntimeDirectory`](https://www.freedesktop.org/software/systemd/man/latest/systemd.exec.html#RuntimeDirectory=)
and [`RootDirectory`](https://www.freedesktop.org/software/systemd/man/latest/systemd.exec.html#RootDirectory=). Then the service just lives in an
empty tmpfs, and the only paths available are whatever is bind-mounted in.

But can this be better? Yes, but we must go into the realm of [capabilities](https://en.wikipedia.org/wiki/Capability-based_security).

# systemd and Capabilities

Capabilities? In my access-control list operating system? It's more possible than you think.
The idea behind capabilities, in short, is something like "if you have access to it, you can use it."
When "it", is generally a token of some sort that has some sort of permission(s) assigned to it. In
Linux-land these tokens are file descriptors (FDs).

The idea of having services secured by capabilities is relatively simple. Take a service, and remove
all access to the system. [Empty read-only file system](https://kernel.org/doc/html//next/filesystems/failfs.html), no network access, nothing.
Well that sounds useful. Finally a secure service, one that cannot read or write anything.

When services are started, systemd has a little stub program it run for setup,
and then it calls [`execve(2)`](https://man7.org/linux/man-pages/man2/execve.2.html)
to start the real service. Most objects cannot cross `execve`: memory is reset,
signals are reset, threads are destroyed. But notably, FDs are preserved (yeah, yeah `FD_CLOEXEC`).

We can just ask systemd kindly to open some files (or file-shaped things), and then those FDs
will be available in the ambient environment of the service.
```ini
# Rest of unit file
# path_to_file:name:perms
OpenFile=/var/lib/thing/config.json:config:read-only
OpenFile=/run/postgres/server.sock:postgres
```
Then either by [reading the manual](https://www.freedesktop.org/software/systemd/man/latest/sd_listen_fds.html),
or using a [handy Rust library](https://github.com/RossSmyth/ambients/), the
service has FDs to these files. Note that the example below may not be 100% correct.

```rust
#[tokio::main]
async fn main() {
  // Safety: I did not access these FDs before, and systemd setup the environment.
  let mut fds = unsafe { ambients::get_ambient_fds().unwrap() };

  let config_fd = fds
      .pop()
      .unwrap()
      .into_kind()
      .into_fd();

  let db_fd = fds
      .pop()
      .unwrap()
      .into_kind()
      .into_fd();

  let mut config_file = std::fs::File::from(config_fd);

  let mut config = String::new();
  config_file.read_to_string(&mut output).unwrap();

  let socket = tokio::net::UnixStream::from_std(db_fd.into());
  let conn = tokio_postgres::Config::new()
      .user("service")
      .database("service")
      .connect_raw(socket, tokio_postgres::NoTls)
      .await.unwrap();

  // Do whatever
}
```
And there you go, a capability-secured service that reads a config and has a database connection.
If you add socket-activation (there are better docs that I for explaining that), then you can also
have your service communicate to the outside world. Probably via a reverse-proxy.

## systemd File Descriptor Store

Huh? File descriptor store? What's that?
Well systemd includes this little store that services can use, and it allows
them to store arbitrary FDs in an attempt to reduce downtime. These FDs can expire
when the service shuts down, or they can expire when systemd does. This means that
a service can store connections across [`kexec`](https://man7.org/linux/man-pages/man8/kexec.8.html)
based system upgrades. 

Another example given is a service storing long-duration socket connections in the store,
then if the service crashes the connection is not closed, and can be immediately acquired again
once restarted by systemd.

This works very similar to the above example in terms of requisitioning the FDs.
But managing them at runtime requires acquiring the systemd notification socket.
The main limitation is that there is no (easy) way to query what is currently in the
store, so the service must do that bookkeeping itself. But it can store FDs, and
remove FDs. This is done via [`sendmsg(2)`](https://man7.org/linux/man-pages/man2/sendmsg.2.html).
A small example is shown below (using an unmerged, not-final API):

```rust
use std::net::{ TcpListener, TcpStream };
use ambients::fd_store::{ socket_store_fd, socket_remove_fd };
use ambients::notify::SysDSocket;
use ambients::get_ambient_fds;

fn handle_connection() {
    todo!();
}

fn main() {
    // Safety:
    // This is the first thing called, and systemd ran this service.
    let ambient_fds = unsafe { get_ambient_fds().unwrap() };

    let _ = ambient_fds
        .iter()
        .find(|fd| fd.get_name() == "connection")
        .and_then(|fd| {
            // If this was a program that handled connections in paralell
            // or handle_connection crashes for some reason, this will process
            // it on start-up
            let connetion: TcpStream = fd.into_kind().into_fd().into();
            handle_connection(connection)
        });
    
    // Safety:
    // This is the first thing called to touch the sysd socket,
    // and this service was setup by systemd
    let sysd = unsafe { SysDSocket::open().unwrap() };

    let socket = TcpListener::bind("127.0.0.1:8080").unwrap();    
    for connection in sockt.incoming() {
        let store_fd = StoreFd {
          fd: connection.as_fd(),
          name: "connection",
        };
        socket_fd_store(&mut sysd, store_fd);

        handle_connection();

        socket_remove_fd(&mut sysd, "connection");
    }
}
```
