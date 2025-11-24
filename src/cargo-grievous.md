# Cargo Grievances: Dang dependencies are hard

Rust's Cargo is a pretty neat tool. It unifies building Rust projects to one
tool, meaning that most projects written in Rust require a single command to
build successfully, `cargo build`. This is a pretty huge step up over other
legacy systems languages such as C & C++ in which every project has its own fun
and unique build system. But it's not perfect. I don't think that is big news to
anyone really. But today I would like to talk about two things that bother me
the most.

## 1. Unaware of native dependencies

Cargo is not aware of native dependencies. If a dependency is not in the
`Cargo.toml` dependencies list, Cargo has no idea what it is nor that it may be
needed. This leads to many ad-hoc solutions that all suck! In general authors do
one of a few things:

1. Build the native dependency from source
1. Use pkg-config
1. Have the person building the program set an environment variable of the
   library location
1. Set a feature that when enabled, links to a native library

Often it is combination of two or all three of them. This really sucks! Since I
prefer using libraries that are up to date, and have security patches, I try to
link to shared libraries as much as I can some my package manager. Cargo makes
this really hard! When building a Rust program, I generally go through the
following process:

1. Build the program without any extra native libraries (beyond glibc)
1. If any dependencies fail to build, see what it requires.
1. Look at every crate built. If any of them are named `*-sys`, open the
   repository holding it.
1. Look at features and see if there is one for enabling native libraries
1. Look at the build script and see if I can substitute a package
   manager-provided library
1. If I cannot, see if it is easy to patch it to do so.
1. If not, give up and just let it do its thing

This is pretty tedious. Now for some libraries I basically know the gist at this
point such as zlib. But other don't write anywhere in their README what
environment variables to set if any, if they try to use pkg-config, or anything.
Just read the build script. Which is fine, I'm a professional Rust dev. But it's
still annoying! If it requires enabling a feature, then I often have to put a
silly patch that enables the feature since most program authors prefer not using
native dependencies.

The most egregious of that is `ureq`, which when the `native-tls` feature is
enabled, it requires the program author to instantiate the library in a way that
is not typical. There's absolutely no reason for that, and is really annoying.

What can Cargo do then? There has been some talk of integrating something like
`pkg-config` into Cargo, then having library authors declare native dependencies
in their `Cargo.toml` manifest. The only real effort into that has been the
[`metadeps`](https://github.com/joshtriplett/metadeps) project, but seems mostly
dead.

I think that the Rust ecosystem needs to get over its obsession with using build
scripts for everything. They aren't that great, and I have access to perfectly
good, usable, and up-to-date shared libraries just one package manager call
away. How should Cargo be aware of this information? Great question! Personally
I wouldn't make Cargo too aware of them, but it should know that they exist, if
only to tell people building executables that they need to.

1. I'd start with adding a key to the `Cargo.toml` manifest like `external-deps`
   Accepts a list of libraries required. These get propagated up to the built
   artifact and are shown on `docs.rs`.
1. Have Cargo read `CARGO_EXTERNAL_<LIBNAME>` environment variables, which can
   be set to the directory to add to the linker search paths.

This seems fairly straight-forward. There's probably issues with it but luckily
this is a blog post and not a design doc. Maybe it could also opportunistically
try to run `pkg-config --libs <libname>` as well.

Now the elephant in the room is Windows. Windows does not really have a package
manager, pkg-config doesn't work well
[or is](https://github.com/rust-lang/pkg-config-rs/pull/165)
[straight-up](https://github.com/mesonbuild/meson/pull/9384)
[broken](https://gitlab.kitware.com/cmake/cmake/-/merge_requests/9375)
[on it](https://github.com/StrawberryPerl/Perl-Dist-Strawberry/issues/11), and
usually libraries are just vendored with every executable. I would still do the
simple "provide environment variables" thing, but some solution would need to be
found. Maybe suggest using `vspkg` or something.

## Update Malaise

The other thing is that it is pretty easy to have insecure executables from
Cargo. Why is that? Well the culture around Rust packaging essentially
encourages it.

1. Many program authors will statically link security-sensitive libraries
   (RustTLS and others)
1. Often instructions for installing will encourage users to install using
   `cargo install`
1. No automatic update process
1. Average user of `cargo install` will not update until either:
   - A new release comes out
   - They remember to do so

Automatic updates are really good! It is a thing that Google Chrome essentially
invented, and has made peoples' computers much much safer. The current Cargo
ecosystem means that say `RustTLS` has a CVE and publishes a new version, every
downstream crate author should probably release an update to bump their
lockfiles (many people use `cargo install --locked`), and encourage people to
actually update their programs. But in reality, this does not happen.
Executables can go a long time without release, and why would an end-user update
a program if it's not broken?

Well, what about other ways of installing? Well installing from GitHub releases
is another thing that is often encouraged. But this is even worse! Then there
are only updates when downstream authors release an update, and if a user
installs a package a few months after a release, they ONLY get an executable
from months ago without any security patches. There's also `cargo-binstall`. I
honestly have no idea when it decides to rebuild executables so I cannot say
much.

Now I know the Linux users in the room are shouting "package manager solve
this!" But in reality they can only do so much. Generally package manager will
universally user `cargo build --locked` so that builds are reproducible. It is
also generally hard to know when a crate needs to be updated. `cargo-auditable`
\+ `cargo-audit` can mitigate this, but not all package managers are doing this.
So most package manager are not in any better state (some are though!).

### What can be done

1. When `rustup update` is used, it should also update everything installed via
   `cargo install`
1. When done updating, `rustup update` should do a check with `cargo audit`
1. Maybe a way to install a service for systemd/windows service manager that
   updates `cargo install`'d programs weekly or so

This would be a pretty huge step. This would update things more often, and also
warn users when things are outdated. If an end-user installs a program from
`crates.io` that hasn't been updated in 4 years, and is on an unsupported semver
of `RustTLS` or other security-sensitive library, it can then warn users.

For program not installed with `cargo install` it is up to package maintainers.
Infrastructure is required. I am a Nixpkgs maintainer, and so I think about this
a lot. Nixpkgs does quite bad at this. I was playing around yesterday and
created [this little prototype](https://github.com/RossSmyth/fetch-cargo-index)
which takes every crates on crates.io, and builds a JSON file with the latest
version. This is a start as it allows a way to programmatically see each latest,
non-yanked, crate. Unfortunately this is not suitable for Nixpkgs because the
output JSON would be required to be vendored into the Nixpkgs repo, which would
more than double the size of the tarball. I only know Nixpkgs so other package
manager would need to do their own research & development.

## Overall

I think one issue with the creation of Cargo is that it conflates two seperate
ideas:

1. Build orchestration
1. Dependency managment

Many languages do this, but what this results in is a bunch of siloed
ecosystems. The closest to avoid this is distro package managers, but they still
fall over at some things. Really my belief is that fetching dependencies, and
building projects should be two seperate programs. This would allow for the
dependency manager to be aware of inter-language dependencies, put them in the
right place, and do the right config. Then the build manager can just build, no
need to touch the network. But for Rust that ship has mostly sailed.
