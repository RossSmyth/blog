# Using Nix: Redux: A Year Later

Alright well it's been a while since I started using Nix. According to my last blog post it was a month
before it was published. That means it's been more than a year since I started using Nix.

## Nix at Home

Nix at home. I have transitioned all of my development into Nix. It's just too useful not to.
My development environments are the same whether I am at work or home, and if they are, they
are just a `jj git fetch` away. This is pretty invaluable because I don't have to think about
the current state of my work laptop or my home desktop and how to reconcile them. I just do it.
Then all my programs are on PATH, all my config files are setup, and I can be right at home.

I also installed NixOS onto my laptop. I don't use my home laptop much, so this was low risk.
Previously it was using Pop_OS. Pop was nice. Now it has NixOS with Niri. This is quite nice.

NixOS is very comfortable, and really I would not want to work in any other environment.

## Nix at Work

All of my projects at work use Nix. They use it for development, building, and CI. Every Sunday
the lockfiles are bumped, and if anything breaks I can fix it on Monday. I did this conversion in
December-January. So far the only time anything has broken was the bump from GCC 13 to GCC 14.

I am a bit annoyed that nixpkgs-native cross-compiling is broken when targeting embedded, but it doesn't
really matter that much.

Using Nix for CI is truly amazing. GitHub runner images are not easy to replicate. I've ran into that
problem many times before I began using Nix. Using Nix for CI is a gamechanger. All my tests run using
a strategy I pioneered when I wrote the [Press Nix library](https://github.com/RossSmyth/press/blob/f99e9f23b527a964392f484ff1e2ffd4bfe5bba7/.github/workflows/main.yml).
Basically each check it ran as its own job. I have found that GitHub caching is too slow to make
a real difference for CI. At least for my uses.

I also need to hand it to [treefmt](github.com/numtide/treefmt-nix). That project is so good. I use
it on almost every project. Another notable mention is [comma](github.com/numtide/treefmt-nix). It is
so so nice to be able to "not install" program just to use them. There are very little programs on my
PATH, mainly just the core tools. Then I just use comma (or devShells) for all other programs.

## Nix as Hobby

I've also fallen down the rabbit hole of packaging in Nixpkgs. Nixpkgs is, at the same time, a truly
awesome project, and also a monstrosity. It is too big to manage at times. Any clean-up takes months.
There are projects maintainerse want to do, but realistically cannot without years to spend pushing
it because there are so many packages. Well over 100,000. You can see what I've contributed [here](https://github.com/NixOS/nixpkgs/pulls/RossSmyth).
I'd like to contribute two things to Nixpkgs:

1. Improve cross-compilation to embedded targets
1. Allow Nixpkgs to natively cross compile to the MSVC ABI

The first goal is currently held up by some other PRs that clean-up the target selection API. The second
goal is held up by me as I am basically starting to build a little stdenv for MSVC applications.

I also like just cleaning up packages. Good examples include [Hunspell](https://github.com/NixOS/nixpkgs/pull/397817),
[Nuspell](https://github.com/NixOS/nixpkgs/pull/442139), and [buck2](https://github.com/NixOS/nixpkgs/pull/437985).
It's nice to improve a derivation. Just some calming janitorial work.

One thing I wish Nixpkgs had was easy to add [ratchets](https://qntm.org/ratchet). There is [nixpkgs-vet](https://github.com/NixOS/nixpkgs-vet/),
but it is not what it needs to be. Ratchets should be easy to add, and not require a whole-ass RFC process to add. There
are clear norms to Nixpkgs that should have ratchets, and they should be able to be easily added. Nixpkgs
recently gained a merge queue, so that's great step to improving merge quality.

## Conclusion

Nix is very idiosyncratic. Personally I think the language itself is fine. It's not what I would've made,
but no one could've guess how big it would become 20 years ago. Other implementations are slowly developing,
and those can help as CppNix's implementation is not that great, and carries a lot of baggage. The true
value in Nix is not the language or runtime, but Nixpkgs. Since that's not going anywhere soon, I will
not either.
