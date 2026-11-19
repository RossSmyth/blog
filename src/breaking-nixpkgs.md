# Breaking Nixpkgs for Security

Hello, if you know me then you know that I am a distro maintainer for
NixOS/Nixpkgs, and that I am a Rust programmer. Recently I did something quite
funny, a
[PR I created was merged](https://github.com/NixOS/nixpkgs/pull/537108/changes#diff-2dad79533e4c2ea67623e4c28dd4edf1ae143fcaed75f41cc4bb714f40eba18f)
that directly broke somewhere around 1000 packages in Nixpkgs, and transitively
broke most of Nixpkgs. We were able to fix most of the big ones in the testing
branch so it wasn't too bad once it hit the rolling release, but the tail of
lesser-used packages is long.

## Why break crates?

Why? Well for security of course. One of our duties as a distro maintainers is
to ensure that users' software is secure. Rust packaging makes this difficult
sometimes due to the commonplace practice of vendoring C libraries into crates,
then building this libraries and statically linking to them. This makes it
difficult for a couple reasons:

1. It is hard to tell if it is actually linked into the final binary
1. Updating these vendored sources is not easy
1. Tracking these vendored sources is not easy

Nixpkgs, like all package distributors, builds Rust packages with the locked
dependencies. This means that if a crate has not been updated in a few months or
years, then it will run with whatever vendored libraries are in the lockfile
from months or years ago. If this touches the internet with crates likes
`aws-lc` or `openssl`, this is not great! These are relatively complex pieces of
C and C++, not well known for being safe, and if there is a vulnerability end
users should be able to update easily.

This creates an unfortunate chain that must occur for end-users to get security
patches. Let's say Elsa Ferris releases a cool little crate that fetches today's
XKCD. This isn't that complicated, so she probably considers her job done with
v1.0. But then let's say for example, a CVE occurs in the native library
`aws-lc`! She is using `reqwest`, which depends on `aws-lc`. An update occurs in
the `aws-lc` crate rather quickly since it is managed by the creators of the
native library. But how do her end-user's get their update? With vendoring, she
must update her lockfile and publish a release. But this is annoying as it means
she must forever update her little program. The alternative is that every user
must constantly monitor all their Rust packages for vulnerabilities, but many
users don't even know what Rust is! They are just using a program they
downloaded.

## What can be done?

This scenario is quite common, except most authors do not update their
applications when there is a security issue in one of their dependencies. This
is not a slight against all you wonderful people, I completely get it. Make your
little tools, and carry on. But as has been shown recently, many of these
vendored crates can be vulnerable! Zstd had a CVE recently, and many crates
vendor TLS certs, which could make them vulnerable to eMudhra!

The alternative is linking via system libraries. On Linux, these are usually
distro-provided. Then pkg-config is able to tell rustc how to link to it.
Hooray! Now end-users are protected as long as the distro updates their library.
But how do you actually tell the crates to use `pkg-config`?

That is the question, and the answer is "read the crate source to figure it
out." There is no standard way. Some crates will probe via `pkg-config`, and
then silently fallback to building from source. Another ad-hoc way is with crate
features; they have a feature that toggles between vendored linking & system
linking. Some allow the user to force linking via `pkg-config` with the build
failing if the probe fails. Some unconditionally link to the native libraries.

In the first case, silently falling back, us distro maintainers must proactively
check to see if there are any crates that do this. This is a bit annoying as it
is not always clear. In the second case, forcing the build the fail, this is
good except there isn't a standard API. We must check each crate anyways to see
what environment variable to set as they are all different. The same story can
be said for features. They are all ad-hoc and different, and we must go and dive
in to find them, then set the feature in the crate. These ad-hoc ones generally
just result in using the vendored source, since most casual maintainers are
either unaware of these vendored sources, or do not think the hassle is worth
it, resulting in end-users running outdated software. In the final case, there
is not much we can do. Build-script overrides exist, but they are quite fragile
and do not work in many cases.

## Making lives easier

How can crate authors improve this situation? Well I highly encourage you to use
[system-deps](https://crates.io/crates/system-deps). This fixes most of the
annoyances. The API is standard, and us distro maintainers can force libraries
to be linked to the distro-provided one, and the crate authors' can provided
fallbacks that build them from source. I highly encourage people to use this,
rather than ad-hoc probing and per-crate environment variables. If you are
worried as a crate author about the effects of linking to a system library, I
recommend constraining your versions properly and investigating if the native
library ever breaks in minor versions. Most do not as they are designed for this
purpose, and will be fine.

You can see an example of switching to `system-deps`
[here](https://github.com/bradlarsen/vectorscan-rs/pull/16/commits/47c0de1c541c795cc180e16c5b10b0c096e15895).
This crate previously unconditionally built from source. Now it probes via
`system-deps` and uses that if the probe succeeds. Currently `system-deps`
requires the end-user to assert that they'd like to fallback to building. This
works around that by falling back if an error is returned.

In the end, we just want our users to be protected, and I hope crate authors do
too! With a bit of work, we can improve the security of our users together.
