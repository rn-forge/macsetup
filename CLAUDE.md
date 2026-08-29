# CLAUDE.md

Guidance for coding agents (Claude Code, Codex, and others — `AGENTS.md` points here) working in this repository.

User-facing documentation lives in [README.md](README.md): what each `rnfmac` command does, the
install/upgrade entry points and their flags, the `macsetup-config` layout, the Homebrew Remote
Relay design and its env vars, and the full `mise run ...` task list. Read it for any of that
instead of duplicating it here — this file covers only what an agent needs beyond it. Generated
per-function API docs are in [`docs/`](docs/) and are never hand-edited.

## Repo map

**macsetup** is a macOS system configuration toolkit (shell/Ruby/AWK) driven by one CLI, `rnfmac`.
Everything under `src/` is the distribution payload; `scripts/build.sh` stages it into `dist/` and
tarballs it for a GitHub Release.

| Path | Role |
|---|---|
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
`commands/<group>/`) adds the sub-command *and* its completion — no registration anywhere.
A `lib.sh` inside a group is shared-helper code, not a dispatchable sub-command.

**Runtime layout:** `~/.rn-forge` (`RNF_HOME`) is the shared home for the rn-forge product family.
Products install to `~/.rn-forge/<product>/<version>/` with `current` → latest; `bin/` and
`completions/` hold one symlink per product. Upgrade/rollback = flip `current`.

**Machine config** lives in the external `macsetup-config` repo, cloned to the persistent
`~/.rn-forge/macsetup/config/` (`CONFIG_HOME`) — outside any versioned `<version>/` dir, so
upgrades never touch it.

**Runtime dependency:** every script sources `~/.rn-forge/shkit/current/shkit.sh` from the external
`shkit` repo (`log_info`, `log_success`, `log_warning`, `log_notice`, `log_error`, `log_verbose`,
`print_vars`). It is not vendored; `install.sh` is the only place that installs it (curling shkit's
own installer — not `source.sh` — or `RNF_SHKIT_INSTALL_BUNDLE` pointing at a local tarball on a
blocked network). Every other script assumes it's present and sources it by absolute path — no
`PATH` dependency; wiring `~/.rn-forge/bin` onto `PATH` is owned by the shell profile.

## Code style

- 2-space indentation, LF line endings (enforced by `.editorconfig` and `shfmt`)
- `shellcheck` with SC1090/SC1091 suppressed (dynamic `source` paths — see `.shellcheckrc`)
- Scripts use `#!/bin/zsh` with `# shellcheck shell=bash` — keep new code bash-parseable (no
  zsh-only expansions) so shellcheck/shfmt can process it; `src/completions/_rnfmac` is the
  zsh-only exception, excluded from both tools
- Every function carries `shdoc` `# @description`/`@arg`/`@stdout`/`@exitcode` annotations;
  `mise run docs` renders them into `docs/`
- Dispatchable scripts end with `${__SOURCED__:+return}` before calling `execute` — that guard is
  what lets shellspec source them without running them

## Invariants and gotchas

These are the decisions that look like bugs or gaps but aren't. Don't "fix" them without asking.

- **A sourced file must define constants and read `$0` at the top level**, never inside a function.
  Under zsh, `readonly`/plain assignments made inside a function that's later `source`d become
  function-local and vanish on return. `src/install.sh` sources shkit *before* defining
  `rnfmac_install()` for exactly this reason.
- **`system/doctor.sh` is presence-only** — it checks that `uv`/`nvm`/`sdkman` exist rather than
  diffing installed runtime versions against the configured ones. Deliberate scope call.
- **`system/sync.sh` skips rather than aborts.** A runtime version with no match, or one that fails
  to install, is logged and skipped so the rest of the sync still runs; the script exits 1 at the
  end if anything was skipped. There is no hardcoded fallback pin in code — at least one of the
  shared or host `<runtime>-versions` file must exist per runtime.
- **`profile/sync.sh` patches `.zshrc` *before* its `source $ZSH/oh-my-zsh.sh` line**, because
  `plugins=()` must be set before oh-my-zsh reads it. Both `.zprofile` and `.zshrc` get their own
  copy of the block: non-login shells (a plain `zsh`, a tmux pane) source only `.zshrc`.
- **`sync.sh` runs `config/pull.sh` first**, so a freshly pulled Brewfile/version pins apply before
  the rest. If the config checkout was *absent* it bootstraps it and stops without applying — that
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
`mise run verify` is the full local gate (see README's Development section for the task list).

- **`system/init.sh` and `system/sync.sh` have no specs by convention, not oversight** — they drive
  real Homebrew/oh-my-zsh/uv/nvm/SDKMAN installers over the network with no mockable seam. That
  surface is verified manually.
- **Coverage is Linux-only.** kcov's line-tracing is a no-op on macOS (confirmed empirically — a
  script that visibly executes still reports 0% covered), so `mise run test`/`verify` never invoke
  it and there is no local coverage gate. The `sonar` job in `.github/workflows/main.yml` runs on
  `ubuntu-22.04` (kcov isn't packaged for noble) and is the one place coverage is generated:
  `shellspec --kcov tests/` produces `coverage/sonarqube.xml`, fed to the SonarCloud quality gate
  via `sonar-project.properties`' `sonar.coverage.reportPaths`.
