## This plugin moved into `daukle/github`

Since `daukle/github@1.1.0` the `github-release` publisher lives in the same plugin as the GitHub
source, because `daukle 0.8.0` lets one chunk declare a source beside `exec`. Your
`[publish.github-release]` block is unchanged; only the `[plugins]` line moves, from
`daukle/github-release@^1` to `github = "daukle/github@^1.1"`. This repository is archived, and its
`1.0.0` release stays downloadable so an existing pin keeps working.
