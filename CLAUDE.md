# CLAUDE.md

Guidance for coding agents (Claude Code, Codex, and others — `AGENTS.md` points here) working in this repository.

User-facing documentation starts in [README.md](README.md). Detailed command behavior is in
[the command guide](docs/guides/commands.md); architecture is documented in the
[runtime layout](docs/architecture/runtime-layout.md),
[configuration model](docs/architecture/config-model.md), and
[Remote Relay design](docs/architecture/remote-relay.md); development tasks and test conventions
are in [the development guide](docs/guides/development.md). Generated per-function API reference
lives under `docs/reference/` and is never hand-edited.

The documentation architecture and source-of-truth boundaries are recorded in
[docs-system.md](docs/architecture/docs-system.md). **Update that page whenever documentation
tooling, generation, validation, or publishing changes.**

## Repo map

**macsetup** is a macOS system configuration toolkit (shell/Ruby/AWK) driven by one CLI, `rnfmac`.
Everything under `src/` is the distribution payload; `scripts/build.sh` stages it into `dist/` and
tarballs it for a GitHub Release.

| Path | Role |
| --- | --- |
| `src/rnfmac.sh` | The dispatcher (see contract below) |
| `src/install.sh` | Standalone sourceable installer, also a release asset |
| `src/commands/` | Top-level sub-commands: `sync`, `doctor`, `version`, `upgrade`, `cleanup` |
| `src/commands/<group>/` | Grouped sub-commands: `system/`, `profile/`, `brew/`, `config/` |
| `src/completions/_rnfmac` | zsh completion; enumerates `commands/` at runtime |
| `src/homebrew/` | Remote Relay patches + strategy class, mirroring Homebrew's layout |
| `src/profiles/shared/` | Static assets sync installs: zsh theme, macOS keybindings |
| `tests/` | shellspec suite, sandboxed `$HOME` (`tests/spec_helper.sh`) |
| `scripts/build.sh` | dist staging + tarball |

**Dispatcher contract:** `rnfmac <sub-command> [args]` → `commands/<sub_command>.sh`, and
`rnfmac <group> <sub-command> [args]` → `commands/<group>/<sub_command>.sh` when
`commands/<group>/` is a directory. Dropping a script into `commands/` (or a new
`commands/<group>/`) adds the sub-command _and_ its completion — no registration anywhere.
A `lib.sh` inside a group is shared-helper code, not a dispatchable sub-command.

The versioned product home, persistent configuration checkout, install/upgrade mechanics, and
external shkit dependency are documented in the architecture pages above; keep their user-facing
explanations there rather than duplicating them here.

## Code style

- 2-space indentation, LF line endings (enforced by `.editorconfig` and `shfmt`)
- `shellcheck` with SC1090/SC1091 suppressed (dynamic `source` paths — see `.shellcheckrc`)
- Scripts use `#!/bin/zsh` with `# shellcheck shell=bash` — keep new code bash-parseable (no
  zsh-only expansions) so shellcheck/shfmt can process it; `src/completions/_rnfmac` is the
  zsh-only exception, excluded from both tools
- Every function carries `shdoc` `# @description`/`@arg`/`@stdout`/`@exitcode` annotations;
  `mise run docs` renders them into the gitignored `docs/reference/`
- Dispatchable scripts end with `${__SOURCED__:+return}` before calling `execute` — that guard is
  what lets shellspec source them without running them

## Invariants and gotchas

These are the decisions that look like bugs or gaps but aren't. Don't "fix" them without asking.

- **A sourced file must define constants and read `$0` at the top level**, never inside a function.
  Under zsh, `readonly`/plain assignments made inside a function that's later `source`d become
  function-local and vanish on return. `src/install.sh` sources shkit _before_ defining
  `rnfmac_install()` for exactly this reason.
- **`system/doctor.sh` is presence-only** — it checks that `uv`/`nvm`/`sdkman` exist rather than
  diffing installed runtime versions against the configured ones. Deliberate scope call.
- **`system/sync.sh` skips rather than aborts.** A runtime version with no match, or one that fails
  to install, is logged and skipped so the rest of the sync still runs; the script exits 1 at the
  end if anything was skipped. There is no hardcoded fallback pin in code — at least one of the
  shared or host `<runtime>-versions` file must exist per runtime.
- **`profile/sync.sh` patches `.zshrc` _before_ its `source $ZSH/oh-my-zsh.sh` line**, because
  `plugins=()` must be set before oh-my-zsh reads it. Both `.zprofile` and `.zshrc` get their own
  copy of the block: non-login shells (a plain `zsh`, a tmux pane) source only `.zshrc`.
- **`sync.sh` runs `config/pull.sh` first**, so a freshly pulled Brewfile/version pins apply before
  the rest. If the config checkout was _absent_ it bootstraps it and stops without applying — that
  preserves the contract that an upgrade never applies configuration.
- **Relay patches are the single source of truth.** `brew/relay.sh` resets `/opt/homebrew` to clean
  and re-applies `src/homebrew/patches/` fresh every time; nothing is cherry-picked from a stored
  commit. Patches can't be authored by hand-editing diff hunks — valid ones need real context lines
  from Homebrew's current sources, which this repo doesn't vendor. That's what `--regen` is for.
- **`config/pull.sh` carries uncommitted local changes across on a stash** rather than refusing
  them (see `config/lib.sh`'s `update_config_checkout`).
- **`upgrade --archive` can legitimately install an older version** than the one installed, so its
  log line is worded as a move, not an upgrade.
- **Install and upgrade are atomic and locked** — staged into a scratch dir, then `rm`+`mv` swapped
  into place, serialized via a `mkdir`-based lock. Archives are verified against a sibling
  `<archive>.sha256` when present, with a warning when not. Keep both paths in step.

## Testing and CI

`mise run test` runs the shellspec suite against a sandboxed `$HOME` with stubbed `curl`/`hostname`.
`mise run verify` is the full local gate (see the
[development guide](docs/guides/development.md) for the task list).

- **`system/init.sh` and `system/sync.sh` have no specs by convention, not oversight** — they drive
  real Homebrew/oh-my-zsh/uv/nvm/SDKMAN installers over the network with no mockable seam. That
  surface is verified manually.
- **`scripts/gen-docs.sh` is excluded from coverage** (via `sonar.coverage.exclusions`), same
  rationale as `system/init.sh`/`system/sync.sh` — dev-tooling invoked from `mise run docs`, not
  the shipped `rnfmac` payload. Verified manually.
- **Docs link/anchor/orphan checking is native MkDocs validation, not a custom script.**
  `mkdocs.yml`'s `strict: true` plus its `validation:` block (`nav.omitted_files: warn`,
  `links.anchors: warn`) makes `mise run docs-site` fail the build on broken links, bad anchors,
  missing nav targets, and orphan pages — no Python doc-linter needed.
- **`src/commands/lib/dedupe-brewfile.awk` is a standalone file, not inlined, and is
  coverage-excluded.** kcov traces bash statement boundaries, not physical lines inside a
  multi-line string argument — an awk script embedded inline in `brew/diff.sh` would report every
  one of its lines as uncovered even when exercised, because kcov never treats them as separate
  statements. Extracting it to its own file (invoked via `awk -f`, same pattern as
  `scripts/shdoc`) keeps the logic covered-by-tests without the false negative.
- **Coverage is Linux-only.** kcov's line-tracing is a no-op on macOS (confirmed empirically — a
  script that visibly executes still reports 0% covered), so `mise run test`/`verify` never invoke
  it and there is no local coverage gate. The `sonar` job in `.github/workflows/main.yml` runs on
  `ubuntu-22.04` (kcov isn't packaged for noble) and is the one place coverage is generated:
  `mise run test-coverage` produces `coverage/sonarqube.xml`, fed to the SonarCloud quality gate
  via `sonar-project.properties`' `sonar.coverage.reportPaths`.
