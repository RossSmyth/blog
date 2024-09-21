# Using Nix

Alright my second blog post every. I think it is customary at this point to make an article about Nix.

Last month I started using Nix. Within a couple weeks I have completely embraced it at work and home for managing builds and configuration of everything I can throw at it.
I now use it for my [development setups](https://github.com/RossSmyth/nixos), almost all of my projects at work (there is one straggler I haven't worked on in a while), and this [website](https://github.com/RossSmyth/blog).

Why?

Well to be honest it is pretty simple. I was quarter-ass replicating what Nix does by hand already.

## Configuration

If you do now know, I primarily work on a Windows machine. This is just a consequence of where I work primarily.
Infamously, Windows doesn't have a package manager. Technically [winget](https://github.com/microsoft/winget-cli).

[Chocolatey](https://chocolatey.org/) exists, and I do use it. It is much more mature than winget, and works fairly well.
Occasionally there is a dead package, but that's usually not a huge deal. [My most starred project ever is a PowerShell script
I made in 15 minutes that generates another PowerShell script that installs all your Chocolate packages](https://github.com/RossSmyth/Windows-Chocolatey-Backup). This was before
Chocolatey had its own XML backup format.

My latest attempt was a tale as old as time. It is essentially the "makefile that configures your system" thing you see Linux people
do. I extremely dislike Make so it is instead Just. It started as my neovim config, but as part of that config I had .bat files that
downloaded and installed [ripgrep](https://github.com/BurntSushi/ripgrep). I stopped using nvim after a few months, but I kept the ripgrep
installer as it was useful. I setup a Windows event that runs every Monday morning that reinstalls it. Eventually I deleted the nvim config,
moved everything from Batch files to Justfiles, and have continued reinstalling all the software I care about keeping updated every Monday.

This continues today as I still use Windows every day. It is about as repeatable as I care about.

## Building Software

This is not really seen on my GitHub repos, but I have spent a lot of time at my job trying to make builds repeatable and easy to configure.
This is much easier said than done, especially since there is a Windows-only [proprietary code generator in the process](https://www.infineon.com/cms/en/design-support/tools/sdk/psoc-software/psoc-creator/).

The status-quo where I work is that builds are not repeatable. A developer builds the production software by clicking "build" on a proprietary IDE on their system.
Whether it works on anyone else's computer or what version anything is don't matter. I've been slowly trying to change this. My first effort
was to move my project to a real build system, and away from IDE tools. So in Februaryish I moved my projects to [Meson](https://github.com/mesonbuild/meson/).
Is it perfectly repeatable? No. Is Meson the best? Also no. But it works well enough that the weird limitations are fine for my purpose. I did not
want to use CMake because every time I have touched CMake in the past nothing has ever worked right. Buck2 and Bazel are mainly for monorepos, no matter what
Google or Facebook folks tell you. I've tried to make them work with my project (I tried using Buck2 before Meson!). I'm sure they are great for what they are
made for. But the documentation for Buck2 is mostly incomprehensible for anyone outside the Buck2 dev team it seems. Bazel is much more mature, but also
has weird idiosyncrasies and being pretty verbose. I have other things to do besides spent days trying to learn just to make a build system compile a few
C files.

Ok, but then the question is where do the compilers come from? Well...that is the tricky part. The default for pretty much every build system is to just pick up
whatever junk it finds in your `$PATH` variable. Which is BAD. People pretty much universally hate the `pip install` global install of packages. This is exactly the same!
Especially when you're like me, and you are cross-compiling to an embedded system. I don't want it to pick up whatever compiler. And I can also go months without working
on projects, and in that time upgrade the compiler for one project, but not another. Upgrading compilers for embedded is always a funny game because the C spec and emebdded
devs are always at odds with each other. You always have to verify that new optimizations didn't do something funny.

My solution was in my Justfile for each project, it would have a hardcoded URL it would download the compiler from. That essentially locked each project to a compiler.
The compiler would get put in a directory within the project. The Meson's cross-file is directed to the path, and everything just works. You could also make this work with
[direnv](https://github.com/direnv/direnv) and installing every compiler you may need. But that is not that great either.

This did some funny things with caching to ensure it only downloaded what it needed since downloading compiler is slow in the Windows environment.

## Nix

### Configuration

Ok, so what does Nix do that solves my configuration problems? Well I just say ["I want ripgrep"](https://github.com/RossSmyth/nixos/blob/cc7e023526e42a89226c1e42a39528dadbb1688b/home-manager/home.nix#L27)
and blamo. It's on my system. The latest one. I also download Helix every Monday morning. Same thing. Helix is even better since the Helix repo has a
Nix flake, so I can get the lastest from the HEAD of the main branch.

And even better, the thing I wanted to do, have all configuration settings in my config repo, it done. [It's all written in Nix.](https://github.com/RossSmyth/nixos/blob/cc7e023526e42a89226c1e42a39528dadbb1688b/home-manager/helix.nix)
That file is equivalent to [these ones](https://github.com/RossSmyth/appdata/tree/main/helix). And it's all unified.

To be honest, it's almost magical. You just declare "do this," switch your nixos config, and it's done. No need to worry about where the config goes. It just works.

### Building Software

Repeatable software takes like ten minutes once you learn how to do it. This does not eliminate the need for Meson or another build system that actually compiles the software. What
Nix does is make the environment that it compiles in repeatable. No matter what computer I am on, the compiler version, the meson version, the python version, the sed version, the bash version,
all of it will be exactly the same. Which IS the problem I always have with building software.

How did I fix the proprietary codegen problem? Well that was easy. I just checked-in the generated software to our repo and stopped having Meson automatically generate it. It doesn't
change very often so it's fine. It does require Windows to generate the code, but there hasn't been a change in the generated code in months. While I would prefer to
generate the code as part of the build process, you win some you lose some. I could probably run it in WINE, but that sounds annoying. And I am not a Linux person so I
wouldn't even know where to start.

There was one tricky little part of moving all of the build process to Linux. That is that the [programmer](https://softwaretools.infineon.com/tools/com.ifx.tb.tool.psocprogrammer) only accepts a limited subset of
the Intel HEX format that I also believe is invalid. Well turns out that's mostly fine. I just reformat the files with [srec_cat](https://srecord.sourceforge.net/man/man1/srec_cat.1.html), delete a couple specific lines with SED, then add in a specific line.
The process of figuring that out took longer than actually implementing it. And since it's all done in Nix, it's all completely repeatable.

Some project have several configurations that within a release all must be built. Since Nix is lazy, I just pretend like they already exist and then they do. Put them in the directory format we need, put the source code beside it,
put a git hash in there, fail the build if the repo is dirty (releases must be checked in!), and put it all in the `$out` directory. Then I even have a derivation that zips the release package into a zip file. They are all done
with Flakes so everything is locked. Some people have issues with Flakes, but they've been great to me.

Now days I also run all [formatting](https://github.com/numtide/treefmt-nix) and tests within Nix as well. An interesting side-effect of this is that
since this is not running on Windows, it avoids the insanely slow [file system filters](https://www.easefilter.com/kb/understand-minifilter.htm) my company has
installed on our laptops. So even when you count the overhead of Nix, it is faster the compile from scratch in Nix than the host Windows environment. Without Nix
it is around 5-10x faster.

## Why not Docker?

Docker is one alternative. But to be honest Docker is such a heavy handed approach to something that should not require it.
spin up a whole container just to have the compiler I wanted? I only use [Nix within WSL](https://github.com/nix-community/NixOS-WSL), and the integration is heavier than you may expect. My development environment,
testing environment, shouldn't require docker containers just to be adequate. Also Docker is not repeatable. At least, it usually isn't. I think
there are ways to make it so, but it requires care.

## Conclusion

I am quite a happy Nix user. It does what I've always wanted my package manager to do. I do have a few reservations:

1. The language is not very good.

One day I will write an article about my language design hot takes.

2. Customization

One thing I like to do is add compiler flags to a few different projects. Nix does NOT make this easy. I can understand why, the goal is to make
repeatable software, just not necessarily the software you want. The main things I want to do are enable Cargo features for some projects,
and compile with native hardware features for some projects like Ripgrep, fd, and Helix. This is not really possible with the current configuration I believe.
I don't care about caching. The main way forward I see for this is a way to specify arbitrary inputs to flakes. Imagine:

```nix
{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    cc_flags.value = "-O3";
  };

  outputs = { self, nixpkgs }: {

    packages.x86_64-linux.default = nixpkgs.legacyPackages.x86_64-linux.stdenv.mkDerivation {
      name = "some-project";
      buildPhase = ''
        gcc ${cc_flags} some_file.c
      '';
      installPhase = ''
        mv out.a $out
      '';
    };

  };
}
```

Or something like that. Then you could override it like any other input.

3. Cross-compilation

Nix theoretically supports cross-compilation easily, but in reality it is half-baked. Not even talking about the whole "flakes don't support cross-compilation".
I am an embedded developer. The way I had to do it is by using the [`gcc-arm-embedded`](https://search.nixos.org/packages?channel=unstable&from=0&size=50&sort=relevance&type=packages&query=gcc-arm) package
in my native environment. The "proper" way is to use something like `pkgs.pkgsCross`, except that's somehow even worse because it just doesn't setup the environment correctly.

In my world there would be no such thing as cross-compilation. Or more accurately, everything would always be "cross-compilation." The build system would have no idea where it's compiling and the concept of "native" wouldn't exist. But this can't exist for a couple reason:

1. GCC is stupid

Each GCC build is only for one target. The solution is to stop using GCC and use Clang like a sane person.

Ok that's mainly it. All the other problems are feeding the compilers the correct build-time dependencies for a target. Like Windows needs special [pthreads](https://github.com/NixOS/nixpkgs/issues/156343) handling and OpenSSL handling.
Embedded targets sometimes need special stdlibs like [Newlib](https://github.com/NixOS/nixpkgs/issues/188817), plus you actually need to pass the target kebab to the compiler and there is no standard on how to form one.
