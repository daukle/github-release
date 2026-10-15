# Authoring notes

Why this plugin is shaped the way it is, for whoever changes it next. The user-facing page is
`CONTENT.md`, which the README is generated from, and `wiki/index.md`, which the public guide
renders.

## Why this is its own repository

**Because a source could not share a chunk with `exec` when this was built.** Until `daukle 0.8.0`,
`lua_declare_source` refused any chunk declaring `exec` or `provision`, and a publisher must exec,
because core can neither POST nor PUT, so `daukle/github`'s chunk could not host this. A second chunk
in that repository was possible, as `daukle/cmake`'s `deps.lua` is, and was declined because every
consumer would need a second resolver block. **`daukle 0.8.0` lifted the rule** (`D-133`, plugin
api 2): a chunk may hold a source and a publisher, and only the source's `load` is refused `exec`.
Moving this publisher into `daukle/github` retires this repository and has not been decided.

## The capability grant is one deliberate omission

`daukle.language`, `daukle.source` and `daukle.resolver` each refuse a chunk declaring `exec` or
`provision`. **`daukle.publisher` does not carry those refusals, and that omission IS the grant.**
Provision is granted as well as exec for a named reason: a publisher that fetches a pinned `gh` is
the ordinary case, not an exotic one.

## What core does and does not do with the token

**Measured 2026-10-13 rather than assumed, because the design depended on it.** Core's credential
handling is narrower than "an env allowlist":

- **`daukle.env` gates exactly two names**, `DAUKLE_TOKEN` and `GITHUB_TOKEN` (`CORE_CREDENTIALS`,
  `src/lua/lua_verbs.c:67`), and refuses them unless the chunk declares them in `env`. **Any other
  name is readable undeclared**, which is what makes a free-form `tokenEnv` work at all.
- **A child process is scrubbed of those same two names, and only when undeclared**
  (`fr_lua_verbs_env_to_scrub`). This plugin declares both, so neither is scrubbed and `gh` also
  inherits an ambient `GITHUB_TOKEN`.
- **`report_verbose_exec` prints the tool, the argv and the cwd and never the environment**
  (`src/lua/lua_verbs.c:1013`), which the publishing spec turned from an accident into a
  requirement. The composing test case depends on it.

**So the refusal for an empty `tokenEnv` is worth its lines**: a project with an ambient
`GITHUB_TOKEN` would otherwise publish through inheritance while the key the manifest names was
unset, which is a success nobody asked for.

## The archive layout is NOT uniform, and Windows is the odd one

**Measured against all three shapes on 2026-10-13, because assuming they agreed would have failed on
the host this was written on:**

| asset | layout |
| --- | --- |
| `gh_<v>_linux_<arch>.tar.gz` | `gh_<v>_linux_<arch>/bin/gh` |
| `gh_<v>_macOS_<arch>.zip` | `gh_<v>_macOS_<arch>/bin/gh` |
| `gh_<v>_windows_amd64.zip` | **`bin/gh.exe`, no leading component at all** |

The unpacker strips nothing, so `lib/gh.lua` returns a full `executable` path rather than a `home`
for the caller to concatenate. That keeps the asymmetry at the table boundary instead of leaking it
into `plugin.lua`, and it is why this table's shape differs from `daukle/java`'s `lib/jdks.lua`.

**There is no `windows/aarch64` asset**, so that host is refused by name.

## `lib/gh.lua` is NOT exported

`exports` on `daukle.plugin{}` governs what ANOTHER plugin may require; a chunk's own
`daukle.require("lib/gh")` needs no entry. `daukle/java` exports `lib/jdks` because `daukle/gradle`
consumes it; nothing consumes this table, and it is an implementation detail rather than a surface.

## Create versus upload is decided by looking

`gh release create` fails if the release exists; `gh release upload` fails if it does not. The step
runs `release view` first with `check = false`, which returns the exit code instead of raising, and
branches on it. **`check = false` is what makes this possible at all**: there is no `pcall` in the
sandbox, so a raising exec could not be recovered from and the plugin would have had to ask the user
which command to run.

## Tests, and what they deliberately do not cover

`test/cases.sh` runs every directory under `test/cases/` against a real daukle. `test/pins.sh`
checks every row of `lib/gh.lua` against the `checksums.txt` the release publishes, **fails on a row
it cannot parse** rather than skipping it, and both negative controls were run: a wrong digest fails,
and a row with no digest fails to parse.

**NOTHING PUBLISHES, on any runner, ever.** The composing case asserts the argv from daukle's own
`--verbose` trace, which is printed before the exec, with `--repo` naming a repository that does not
exist.

**Measured while writing that case, and it makes the case safer than designed**: `gh` validates the
asset file locally *before* contacting GitHub (`no matches found for 'greeter.jar'`), so the case
fails without a single network call. **What that also means is that no test reaches the API**, so
"the command is well formed enough for GitHub to answer it" is unverified here, and so is any
upload. The first real upload will be a release of something, under the STOP point.

**A case's `expect-error.txt` holds ONE clause, not several.** The harness reads the whole file and
greps `-F`, which treats several lines as alternatives, so a two-line file asserts an OR while
reading like an AND. `expect-output.txt` is the one that loops per line. Measured in
`daukle/gradle`'s harness while writing a two-line expectation there.

**The fixture toolchain is the smallest thing that satisfies `from`.** A publish step runs in a
toolchain's derived directory and carries its context, so a publisher cannot be exercised without a
declared toolchain; `test/cases/*/fixtures/toolchain.lua` declares one that builds nothing.
