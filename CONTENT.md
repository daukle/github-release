## What this plugin is

A `daukle.publisher` named `github-release`. It takes files a toolchain built and uploads them as
assets on a GitHub release, through a `gh` it provisions and pins by sha256. Your repository holds
`daukle.toml` and sources, and no publishing plugin, no `gh` on the host and no token in any file.

**It is the first publisher in the org.** Core has carried the whole mechanism since `daukle 0.3.0`
and nothing used it: `daukle.publisher{}`, `[publish.<name>]`, `daukle publish`, and an
exec-and-provision grant that exists for no other reason.

```toml
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

## A publisher cannot order itself, and this is the one thing to read

**No plugin declares `build`, and a publisher may declare no `dependsOn` of its own**, because it
cannot know the toolchain's name until the manifest says `from`. So a destination with nothing wired
uploads whatever was last built, or fails on a file that is not there. The `[tasks."publish:..."]`
block above is not decoration.

## The token is a variable name, never a token

`tokenEnv` names an environment variable and defaults to `GITHUB_TOKEN`. daukle reads it, hands it
to `gh` as `GH_TOKEN` for that one process, and **core never copies, stores or prints a credential**:
`--verbose` traces the tool, the argv and the directory, and never the environment.

A variable that is empty or unset is refused by name before anything runs, because `gh`'s own
message for a missing token says nothing about which variable daukle looked in.

## Which command runs is the forge's answer, not a key

`gh release create` fails if the release exists and `gh release upload` fails if it does not, so
asking you to state which one applies would be asking for something the forge already knows. The
step looks first, then creates the release or adds to it with `--clobber`.

A release created here always carries a note, defaulting to the project and version, because `gh`
opens an editor when a release is created with no body, and in CI that is a job that hangs rather
than one that fails.

## There are no globs

daukle runs no shell, so `build/libs/*.jar` reaches `gh` as a literal asterisk. Spell every file,
and interpolate a version with `{version}`, which is substituted in `files` and in `tag` from the
manifest's own `version`. An asterisk is refused with that sentence rather than left to `gh`.

| key | meaning |
| --- | --- |
| `from` | core's own, required: the toolchain whose derived directory the step runs in |
| `repo` | `owner/name` to release into. Required, and never guessed from the project id, which only resembles one |
| `files` | the files to upload, each spelled exactly, relative to that derived directory |
| `tag` | the tag to create or add to, `{version}` interpolated. Defaults to `{version}` |
| `tokenEnv` | the NAME of the variable holding the token. Defaults to `GITHUB_TOKEN` |
| `notes` | the release body, used only when the release is created. Defaults to `<project> <version>` |

## What it does not do

**It does not check that a file exists**, and cannot: there is no listing verb, `daukle.read` raises
rather than returning nothing, and the sandbox has no `pcall`, so the only route is to let `gh`
report it. It reports it before contacting GitHub.

**It does not publish to Maven, or to GitHub Packages.** A second destination is a second publisher.
Measured over 347 live build files in the tree this was written for, 50 configure a GitHub release
against 37 using `maven-publish`, which is why this one came first.

**It pins ONE `gh`, not a range**, unlike a toolchain's version table. Which Gradle or JDK a project
builds with is the project's decision and belongs in its manifest; `gh` is this plugin's own
implementation detail, and nothing a user writes names it.
