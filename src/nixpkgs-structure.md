# The experience of contributing to Nixpkgs sucks, structurally

Hello there, it is I. As you may or may not know, I have been using NixOS for
nearly two years now. I love Nix and NixOS not because they are perfect, but
because they are the least bad in my opinion. That is an opinion shared by many
users of Nix. "It's not great, but find me something better." Nix, the
interpreter, is also infamously extremely ossified and drama-laden. Many design
decisions made were not forward-thinking, and it hurts. Nixpkgs, the package
repo that uses Nix, the interpreter, to build NixOS and software packages, it
not quite as ossified. But it is also a nearly 20 year old repo, and needs
improvement.

So, how do you go about improving such a thing? Well for the most part, you
don't. Which is to say, one person cannot make a change. The best way is to find
people who are attracted to your project, and let them get nerd-sniped into
changing little bits at a time. Nixpkgs does this! `strictDeps` and
`__structuredAttrs` are now required to be true for all new packages, formatting
is required, and a merge queue is now used.

# Change flow

How do these changes get implemented? Well let's look at how a change is done to
Nixpkgs:

1. Someone submits a PR on GitHub
1. PR is reviewed by one or more people
1. PR is approved
1. PR is sent to the merge queue by a committer

Note that final point. There is the concept of a "Nixpkgs committer" who has a
"commit bit." These folks are considered to be people who set the standard of
Nixpkgs, and get the final say on what is actually committed. Most of the
automated tooling revolves around the approval of a Nixpkgs committer, either
directly or indirectly. How many of these committers are there? If I was not
able to see the list of committers I would guess a few dozen or so. Nope,
there's around 300 Nixpkgs committers. You would never know in day to day work
though.

# Committers and what they do

If you make a PR to Nixpkgs, there is a 99.9% chance your PR will be reviewed by
one of a dozen people. Their bandwidth is low, and the work they do is mostly
thankless. Do I agee with everything they say? Absolutely not. But they are the
ones on the front lines making sure things are actually read.

I do think Nixpkgs should accept less packages. With the advent of the LLM
policy, the amount of slop being PR'd is extremely high, and a lot of reviewer
time is spent on such slop. Reviewers need to be less afraid to look at
upstreams that were created two weeks ago and are used by 1 person, and say "no
this doesn't belong in Nixpkgs." But Nixpkgs has a reputation is accepting most
any applications.

So if there are about a dozen committers that review PRs regularly, what do they
others do? I have reviewed many of them and their impact:

1. Nothing, no commits in a long time
1. They commit their own PRs
1. They hyper focus on one tiny corner of Nixpkgs

Well that's nice. I'm glad people have hobbies. Ask any one of these committers
if Nixpkgs needs to be improved/cleaned-up and I'm sure 100% will say "yup." But
you'll never catch most of them looking at any PRs.

# My experience

I have been committing to Nixpkgs for well over a year now. I'm semi-paid to now
as part of our infra at work uses it (only like two packages). Working on
Nixpkgs is an exercise of endurance. How long can you wait for a review, how
long can you beg for reviews, how many review cycles can you go though, how many
bike sheds can you paint? It is exhausting. I have several Nixpkgs projects I'm
working on. But none of them have even made it past the first PR yet.
[I recently dropped myself from the majority of packages I have been maintaining](https://github.com/NixOS/nixpkgs/pull/526206)
Not because I wanted to, but because I can't even get eyes on the packages that
I really want to work on, let alone the stragglers. This post is basically me
kicking and screaming and crying. I want to help Nixpkgs improve, I really do.
But how? How can I get people to even give me the time of day? FOSS maintainers
cannot be forced to do anything as they are just volunteers. That is why I say
it is "structural." The structure of how Nixpkgs sets up its review cycle makes
it so that real improvments do not get eyes, while adding another LLM generated
package does.

# What could be done

Committers don't have much reason to ever look at Nixpkgs once they have the
commit bit. There are hundreds of them! Take some responsibility as the "best of
Nixpkgs," and try to help. What the Rust project does with review assignment is
probably the most sane solution, where they are assigned round-robin taking into
account availability. Even if there was a separate "reviewers" team that people
could opt-out from, it would be better.
