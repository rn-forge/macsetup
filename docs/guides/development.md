# Development

Everything goes through `task`. Nobody — human, agent or CI — invokes `uv`,
`pytest`, `ruff`, `pyright`, `mkdocs` or `kiln` directly; `kiln doctor`'s
`ci-entrypoint` check fails the build if a workflow step does.

```bash
task setup       # sync the venv with the dev and docs groups
task validate    # the whole gate: lint, typecheck, test, docs build
task format      # ruff format + fix, in place
task docs:serve  # live docs on http://127.0.0.1:8080
```

## The ten root verbs

`setup`, `validate`, `lint`, `format`, `typecheck`, `test`, `test:coverage`,
`build`, `clean`, `version` — plus the public `docs:build`, `docs:serve`,
`docs:generate`. Every other task is `internal: true` and exists to be composed
by a wrapper. That list is fixed by kiln ADR-0007, and `kiln doctor`'s
`task-layout` check fails if a gate stops being reachable from `validate`.

## After changing a generated file

Don't. Change `.rn-forge/kiln/config.toml` and run `kiln apply`. If you edited
one anyway, `task lint` will tell you which file drifted and from what.

## After adding a docs page

Run `task docs:generate` — `task lint` fails on a stale nav.

## The shell product

macsetup is mid-port from shell to a kiln `python-tool`
([the plan](../specs/python-tool-port.md)). Until the cutover the shell `rnfmac`
in `shell/` is what ships, and it is built and tested with mise, not `task`. The
Python package in `src/rn_forge/macsetup/` is the scaffold it is being ported
into: its `ToolProduct`, and the zsh theme, keybindings and Homebrew Remote
Relay patches it will install, packaged under `assets/` and read through
`rn_forge.macsetup.assets`. Those assets are copies of the files under
`shell/profiles/shared/` and `shell/homebrew/`; a test fails if the two differ.

The ported read-only commands follow one pattern: a Typer function in
`commands/` over a service in `services/` that takes a `Layout` (paths resolved
from `$HOME`/`$RNF_HOME`) and a `Runner`, the one seam for `git`, `brew`,
`hostname` and `uv` (`domain/runner.py`; the real one is `adapters/process.py`).
Tests replace the runner with `FakeRunner` from `tests/support.py`, which
scripts everything but `git`, and an autouse fixture in `tests/conftest.py`
points `HOME` and `RNF_HOME` into `tmp_path`. Run them with
`RNF_HOME=/nonexistent-guard task validate`.

Run `RNF_HOME=/nonexistent-guard mise run verify` for the shell product. The
spec helper pins `RNF_HOME` and `HOME` to a sandbox, but a stray `RNF_HOME`
exported in your shell must never reach an installer.

### Checkout

The shell product is shell, Ruby, and AWK. Its development tools are pinned with
[mise](https://mise.jdx.dev/) in `.mise.toml`; ShellSpec is installed separately
because mise has no plugin for it.

```sh
mise install
mise run verify
```

### Tasks

| Command | Purpose |
| -- | -- |
| `mise run format` | Format shell scripts in place with shfmt. |
| `mise run format-check` | Check shell formatting without changing files. |
| `mise run lint` | Run shellcheck over shell scripts. |
| `mise run test` | Run the ShellSpec suite under zsh. |
| `mise run test-coverage` | Run ShellSpec under kcov and produce `coverage/sonarqube.xml` (Linux only). |
| `mise run docs` | Generate shell API reference under `docs/reference/shell/` (gitignored). |
| `mise run build` | Stage `dist/macsetup` and build the release archive. |
| `mise run verify` | Run the shell product's gate: format-check, lint, test, build, docs. |
| `mise run clean` | Remove generated distribution artifacts. |
| `mise run bump <patch\|minor\|major>` | Update `VERSION`; review and commit it yourself. |

`mise run verify` is the shell product's gate. The documentation site is built
by `task docs:build`; run `mise run docs` first to include the shell reference
in it.

### Tests and coverage

`tests/` contains ShellSpec examples for install, upgrade, cleanup,
orchestration, diagnostics, profiles, configuration, Brewfile management, and
the relay. Tests run against a sandboxed `HOME` with stubbed external commands;
see `tests/spec_helper.sh`.

`shell/commands/system/init.sh` and `shell/commands/system/sync.sh` are verified
manually by convention because they drive real Homebrew, oh-my-zsh, uv, nvm, and
SDKMAN installers without a mockable seam.

There is no local macOS coverage gate. kcov line tracing reports no useful shell
coverage on macOS, so the Sonar job runs `mise run test-coverage` on Ubuntu
22.04 and sends `coverage/sonarqube.xml` to SonarCloud.

### Code and documentation conventions

- Use two-space indentation and LF line endings.
- Write scripts for zsh with `#!/bin/zsh` and `# shellcheck shell=bash`, but
  keep them bash-parseable; the zsh completion is the exception.
- Add `shdoc` annotations to every function.
- Keep `${__SOURCED__:+return}` before `execute` in every dispatchable script.
- Run `mise run docs` after changing annotations; generated reference files are
  not committed or hand-edited.

For architecture and non-obvious implementation constraints, read `CLAUDE.md`
before changing code.
