# Breaking Nixpkgs for Security

Nixpkgs is the largest official Linux distribution package set. There are somewhere around 120k packages in the set at this point in time.
Maintenence of such a colassal package set is dfficult and relatively thanksless. There are hundreds of PRs submitted every day, and around 250
Nixpkgs committers at this point in time who are authorized to merge these patches.

## What is Nix?

If you know what Nix is, you can skip this section.

Nix is a language that allows users to specify an execve call in a lazy, purely function language that can be ran on any computer, and then trasnferred
to the final machine soundly. What "sound" means in this case is essentially "as written," which is usually something along the lines of "the final executable
will not be broken, and will refer to the exact dependencies that were specified in its build inputs." This allows for multiple versions of the same executable
and library on the same machine (even the same version with different build configuration), and they will not interfere with each other. So I can have 3 different
configurations of sqlite3 installed on my machine, and they won't interfere with eachother with strange loader errors.

The way this is accomplished is that everything lives inside the "nix store", which is a read-only directory where all things built with Nix live. All builds (called "derivations"),
have their inputs specified, and the builds run inside a Linux namespace without any access to the host system or networking (localhost within the namespace is allowed). If you look inside
this namespace, it's just an empty directory. Paths are setup so that the build tools know where in the nix store to look (generally via pkg-config and other environment variables).

The build is ran, and an output is created in the nix store. The Nix build daemon scans this output for any references to the nix store paths of the build inputs. If there are, it
writes those references down in the nix sqlite db. This output can then be copied to other machines soundly, as all references will be copied to the target machine first, then the
final package will be copied.

There is one case where a restriction is relaxed though. It is quite useful to be able to download the source code of packages before building a package. But Nix inherently does not
trust the network to remain pure, so some other way was designed to ensure that downloads are pure. This is by specifying their content-addressed hash ahead of time in what is called a "fixed-output derivation (FOD)".
The sha256 of the source code is written down, the download occurs (Nix does not know how this download occurs, though in practice it is via curl), the output directory is hashed, and if it does
not match the hash written down the build fails. Since the content is hashed this download generally only needs to happen once, then the network is never accessed again.

## Rust Packages

Rust packages are commonplace now days. There is a derivation builder called `buildRustPackage` that does most of the work, though it's just a wrapper around some
Bash hooks. But Rust packages have a problem. Nixpkgs does not package each dependency individually, rather it downloads all dependencies for a given Rust package
in a FOD to a `cargo vendor` compatible directory. Then it writes a `config.toml` file so that Cargo will build with this vendored directory. The problem is that
`aws-lc-rs` by default builds a vendored `aws-lc` statically. These means that if a Rust package `cool-downloader` makes a release tomorrow, then next week `aws-lc`
has a critical CVE and releases a patch, in two weeks `cool-downloader` will still be running this old, unpatched `aws-lc`. Generally downstreams (in this case `cool-downloader`) do not make releases
based upon their dependencies, though there are some exceptions. So if a Rust crate nominally works, it still may be running a rustls from 2024, with a statically linked openssl
from then as well as its cryptography backend. That's not great for end-users.

People have been kicking around different ideas on how to solve this problem. Many ideas would require repackaging every Rust package uses new packaging infrastructure that
does not exist yet. So I proposed an idea that can happen now: what if we just [break every package that statically links various lirbaries](https://github.com/NixOS/nixpkgs/pull/537108/changes)?
Folks accepted that this is probably the lowest friction solution in the short-term. Just it will require an effort to patch each package, but the patches are simple: just add the missing library to the build inputs.

## Staging

The way that changes that effect many packages are merged into the tested branches of Nixpkgs is via a process called "staging." The change is merged to the staging branch, then every couple weeks
that branch is frozen to "staging-next," which is then tested and built until most of the issues are shaken out, the packages are built, and then staging-next is merged into the tested branch "nixpkgs-unstable."

The main discovery in this staging cycle is that the way Nixpkgs built `aws-lc` before meant it could not coexist with openssl, and there are a few
Rust package that depend on both. This is because `aws-lc` has a openssl shim, so the symbols would collide and linking would fail. The was solved by
making our `aws-lc` have its symbols prefixed, which the `aws-lc-rs` crate configures with properly. There are a few non-Rust crates that use `aws-lc` that
were not quite happy with prefixing, but they were dealt with.


## The Future

There are still many libraries that Nixpkgs could link into Rust libraries, but does not have any good tooling for detecting. I have some plans for these, but
will have to see how motivated folks are for more breaking of Rust packages.

For Rust crate authors, I mainly recommend to use the [`system-deps`](https://crates.io/crates/system-deps) crate. I think it is by far the most sane in how
it deals with native libraries. There are many build scripts that either probe via pkg-config, but have no way to tell it to abort if the probe fails, so it
is difficult for distro maintainers to know that it is building a pinned library from source. Build scripts are often quite ad-hoc, so that is why I recommend `system-deps`.
as it standardizes parts of the API. I know that crate authors sometimes what to link specific revision of native libraries, and we can build specific revisions too
in the distro repo, we just need to know that it is happening in the first place. You can always fall back to building from source if you want, we would just like the oppurtunity
to tell it not to so that it is easier for us to track what crates depend on what libraries.

## Side-note

I am aware of cargo-audit, the problem with it is that there are many false-positives which make it difficult to automate anything with its outputs. All it can do is tell us
if a package had a version of i.e. `aws-lc` in the `Cargo.lock` file, not whether it was actually linked in. 
