## What this plugin is

A `daukle.publisher` named `github-release`. It takes files a toolchain built and uploads them as
assets on a GitHub release, through a `gh` it provisions and pins by sha256. Your repository holds
`daukle.toml` and sources, and no publishing plugin, no `gh` on the host and no token in any file.

**It is the first publisher in the org.** Core has carried the whole mechanism since `daukle 0.3.0`
and nothing used it: `daukle.publisher{}`, `[publish.<name>]`, `daukle publish`, and an
exec-and-provision grant that exists for no other reason.

## It is NOT built yet

**This repository is the granted home for that plugin and holds no `plugin.lua` today.** The design
is `daukle/docs`' `superpowers/specs/2026-10-13-github-release-publisher-design.md`, written before
any code, and its section 12 names the four things it does not prove. The manifest generator skips
a repository with no `plugin.lua`, so nothing here appears on the public site until it does.

## The one thing to read first

**A publisher cannot order itself.** No plugin declares `build`, and a publisher may declare no
`dependsOn` of its own, because it cannot know the toolchain's name until the manifest says `from`.
So a destination with nothing wired publishes whatever was last built:

```toml
[tasks."publish:github-release"]
dependsOn = ["java:jar"]
```
