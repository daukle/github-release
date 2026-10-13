# daukle/github-release

A **publisher**: it ships what a toolchain built. This one uploads files as assets on a GitHub
release, through a `gh` it provisions and pins by sha256, so nothing has to be installed on the host
and no token is written in any file.

## Declaring it

```toml
[plugins]
github-release = "daukle/github-release@^1"

[toolchains.java]
main = "example.Greeter"

[publish.github-release]
from = "java"
repo = "example/greeter"
files = ["greeter.jar"]

[tasks."publish:github-release"]
dependsOn = ["java:jar"]
```

```sh
daukle publish                   # every destination the manifest declares
daukle publish github-release    # one of them
```

## That last block is the one to not leave out

**A publisher cannot order itself.** No plugin declares `build`, and a publisher cannot know the
toolchain's name until the manifest says `from`, so it may declare no `dependsOn` of its own. A
destination with nothing wired uploads whatever was last built, or fails on a file that is not
there.

## Keys

| key | meaning |
| --- | --- |
| `from` | core's own, required: the toolchain whose derived directory the step runs in |
| `repo` | `owner/name` to release into. Required, and never guessed from the project id, which only resembles one |
| `files` | the files to upload, each spelled exactly, relative to that derived directory. `{version}` is interpolated |
| `tag` | the tag to create or add to. Defaults to `{version}` |
| `tokenEnv` | the NAME of the environment variable holding the token, never a token. Defaults to `GITHUB_TOKEN` |
| `notes` | the release body, used only when the release is created. Defaults to `<project> <version>` |

## The token

The manifest names a variable and daukle reads it, handing it to `gh` for that one process.
**Core never stores or prints a credential**: `--verbose` traces the tool, the arguments and the
directory, and never the environment. A variable that is empty or unset is refused by name, because
`gh`'s own message for a missing token does not say which variable daukle looked in.

## There are no globs

daukle runs no shell, so `build/libs/*.jar` would reach `gh` as a literal asterisk. Spell every
file; an asterisk is refused with that reason rather than passed on.

## What it cannot show you

**No test here publishes anything**, so "it uploads" is proven by use and not by the suite: the
cases assert the exact command from daukle's own trace, against a repository that does not exist.
`gh` checks the files before it contacts GitHub, so those runs make no network call at all.

**It pins one `gh`**, not a range: which Gradle or JDK a project builds with is the project's
decision, while `gh` is this plugin's own implementation detail and nothing you write names it.
