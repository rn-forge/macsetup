# Development

## Checkout

The repository is pure shell, Ruby, and AWK. Development tools are pinned with [mise](https://mise.jdx.dev/) in `.mise.toml`; ShellSpec is installed separately because mise has no plugin for it.

```sh
mise install
mise run verify
```

## Tasks

| Command | Purpose |
| --- | --- |
| `mise run format` | Format shell scripts in place with shfmt. |
| `mise run format-check` | Check shell formatting without changing files. |
| `mise run lint` | Run shellcheck over shell scripts. |
| `mise run test` | Run the ShellSpec suite under zsh. |
| `mise run test-coverage` | Run ShellSpec under kcov and produce `coverage/sonarqube.xml` (Linux only). |
| `mise run docs` | Generate shell API reference under `docs/reference/`. |
| `mise run docs-lint` | Check documentation links, anchors, and navigation reachability. |
| `mise run docs-site` | Build the strict MkDocs site into `site/`. |
| `mise run docs-serve` | Serve the documentation with live reload. |
| `mise run build` | Stage `dist/macsetup` and build the release archive. |
| `mise run verify` | Run the full local and CI gate. |
| `mise run clean` | Remove generated distribution artifacts. |
| `mise run bump <patch\|minor\|major>` | Update `VERSION`; review and commit it yourself. |

`mise run verify` is the required gate. The generated reference must be regenerated before the documentation lint and strict site build.

## Tests and coverage

`tests/` contains ShellSpec examples for install, upgrade, cleanup, orchestration, diagnostics, profiles, configuration, Brewfile management, and the relay. Tests run against a sandboxed `HOME` with stubbed external commands; see `tests/spec_helper.sh`.

`src/commands/system/init.sh` and `src/commands/system/sync.sh` are verified manually by convention because they drive real Homebrew, oh-my-zsh, uv, nvm, and SDKMAN installers without a mockable seam.

There is no local macOS coverage gate. kcov line tracing reports no useful shell coverage on macOS, so the Sonar job runs `mise run test-coverage` on Ubuntu 22.04 and sends `coverage/sonarqube.xml` to SonarCloud.

## Code and documentation conventions

- Use two-space indentation and LF line endings.
- Write scripts for zsh with `#!/bin/zsh` and `# shellcheck shell=bash`, but keep them bash-parseable; the zsh completion is the exception.
- Add `shdoc` annotations to every function.
- Keep `${__SOURCED__:+return}` before `execute` in every dispatchable script.
- Run `mise run docs` after changing annotations; generated reference files are not committed or hand-edited.

For architecture and non-obvious implementation constraints, read `CLAUDE.md` before changing code.

