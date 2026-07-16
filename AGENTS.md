# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## Commands

Tasks run via `mise`:

```sh
mise run format        # format shell scripts with shfmt (in-place)
mise run format-check  # dry-run format check (CI)
mise run lint           # shellcheck all shell scripts
mise run test            # run the shellspec suite (tests/)
mise run docs            # regenerate docs/ from shdoc annotations in src/ — never hand-edit docs/
mise run build            # generate dist/macsetup + dist/macsetup.tar.gz
mise run verify           # format-check + lint + test + build + docs (full CI gate)
mise run clean             # remove dist/
```

Required tool versions are pinned in `.mise.toml`: `shellcheck 0.11.0`, `shfmt 3.13.1` (`shellspec` is not pinned there — CI installs it via a direct curl install script, since mise has no shellspec plugin). `tests/` holds a `shellspec` suite (specs for install, upgrade, cleanup, profile sync, brew sync/relay, and the `rnfmac` dispatcher) run against a sandboxed `$HOME` with stubbed `curl`/`hostname` (`tests/spec_helper.sh`). `system/init.sh` and `system/sync.sh` have no specs by convention, not oversight: they talk to real Homebrew/oh-my-zsh/uv/nvm/SDKMAN installers over the network with no mockable seam, so that surface is verified manually instead.

Coverage (`kcov`) was evaluated and deliberately skipped: it installs and runs on macOS but its line-tracing is a no-op there (confirmed empirically — a script that visibly executes still reports 0% covered lines). Don't add a coverage gate here.

## Architecture

This is **macsetup** — a macOS system configuration toolkit (shell/Ruby/AWK) driven by one CLI, `rnfmac`. Everything under `src/` is the distribution payload; `scripts/build.sh` stages it into `dist/` and tarballs it for a GitHub Release.

**Dispatcher contract:** `src/rnfmac.sh` maps `rnfmac <sub-command> [args]` → `commands/<sub_command>.sh`, and `rnfmac <group> <sub-command> [args]` → `commands/<group>/<sub_command>.sh` when `commands/<group>/` is a directory. Dropping a script into `commands/` (or a new `commands/<group>/`) adds the sub-command and its zsh completion (`completions/_rnfmac` enumerates the dir at runtime) — no registration anywhere. A `lib.sh` inside a group (e.g. `commands/profile/lib.sh`) is shared-helper code, not a dispatchable sub-command.

**Top-level commands** (`src/commands/`):

- `sync.sh` — the everyday command. Composes `profile/sync.sh` → `brew/sync.sh` → `system/sync.sh`, in that order (profile first so a new dist's Brewfile/pins apply before the rest runs). `RNFMAC_SYNC_PROFILES_ONLY=1` skips the brew/system steps.
- `doctor.sh` — read-only health sweep: `system/doctor.sh` + `profile/check.sh` + `brew/diff.sh`. Exit 0 healthy, 1 if any group reports drift.
- `version.sh` — prints the installed VERSION.
- `upgrade.sh` — downloads the latest GitHub release tarball and installs it as a new version dir, flipping `current`.
- `cleanup.sh` — deletes every installed version dir under `~/.rn-forge/macsetup/` except the one `current` points to (upgrade/install never prune old versions themselves, so this is the explicit opt-in to reclaim disk space).

**Command groups:**

- `system/` — `init.sh` (one-time bootstrap: Homebrew, oh-my-zsh + plugins, uv, nvm, SDKMAN, the Homebrew Remote Relay; `--force` reinstalls everything), `sync.sh` (installs pinned runtimes: Python 3.15 via uv, Node LTS via nvm, Java 21 Temurin via SDKMAN), `doctor.sh` (read-only toolchain health check — presence-only, e.g. checks `uv`/`nvm`/`sdkman` exist rather than diffing installed runtime versions against the pins; that's a deliberate scope call, not a gap to silently "fix").
- `profile/` — `sync.sh` (renders shared+host `profile.zsh` into `~/.rn-forge/macsetup/profile.zsh`, patches `.zprofile`/`.zshrc`, backs up existing rc files first — `.zshrc`'s patch is inserted before the `source $ZSH/oh-my-zsh.sh` line specifically because `plugins=()` must be set before oh-my-zsh reads it, and non-login shells like a plain `zsh` or a tmux pane only source `.zshrc`, not `.zprofile`, so both rc files need their own copy of the block), `check.sh` (read-only: does the installed profile match what sync would render), `lib.sh` (shared rendering helpers, not a sub-command).
- `brew/` — `sync.sh` (`brew bundle install` + `cleanup` against the host's `Brewfile`), `diff.sh` (read-only drift report; `--write` updates the Brewfile from installed state, requires a git checkout), `relay.sh` ((re)applies the Homebrew Remote Relay patches; `--force` resets+reapplies, `--reset` reverts to Homebrew's clean base, `--regen` regenerates the patch files themselves from a hand-edited clean-base Homebrew worktree — patches can't be authored by hand-editing diff hunks since valid ones need real context lines from Homebrew's current sources, which this repo doesn't vendor).

**Install/upgrade path:** `src/install.sh` is a standalone, sourceable installer (also published as a release asset) — `. <(curl -fsSL .../install.sh)` on a fresh machine (streaming: downloads the latest release tarball, verified against its `.sha256` sidecar when present), or `. src/install.sh` from a checkout/unpacked dist (in-path: installs straight from the sibling tree, no network round-trip for macsetup itself — detected via a sibling `rnfmac.sh` + `VERSION`). Either way the actual copy into `~/.rn-forge/macsetup/<version>/` is atomic (staged into a scratch dir, then `rm`+`mv` swapped into place) and serialized against concurrent installs via a `mkdir`-based lock, then `current` is symlinked and `bin/rnfmac` + `completions/_rnfmac` are linked in. It does not touch `.zprofile`/`.zshrc` or run bootstrap/sync — that's `rnfmac system init` / `rnfmac sync`. `commands/upgrade.sh` mirrors this hardening (atomic swap, checksum check) but is streaming-only — it always operates on an already-installed instance and always fetches the newest release, so there's no in-path case for it.

**Runtime layout:** `~/.rn-forge` (`RNF_HOME`) is the shared home for the rn-forge product family. Products install to `~/.rn-forge/<product>/<version>/` with `current` → latest; `bin/` and `completions/` hold one symlink per product. Upgrade/rollback = flip `current`.

**Machine profiles** live under `src/profiles/<hostname>/` — each has a `profile.zsh` (machine-specific env vars) and a `Brewfile`. `src/profiles/shared/` holds the common shell config (`profile.zsh`), the custom zsh theme, and macOS keybindings. At sync time, shared + host `profile.zsh` are concatenated (host wins by coming last).

**Homebrew Remote Relay** (`src/homebrew/` — mirrors Homebrew's internal layout) solves corporate network/Zscaler blocks. When `HOMEBREW_REMOTE_RELAY_ENABLED=1`, Homebrew downloads are proxied via SSH to `HOMEBREW_REMOTE_RELAY_HOST` (default: `rohitnarayanan@rohitmacmini.local`), which fetches the artifact and SCPs it back. `commands/brew/relay.sh` resets the local Homebrew install (`/opt/homebrew`, Apple Silicon only) to clean and re-applies the patches in `src/homebrew/patches/` fresh each time — patches are the single source of truth, nothing is cherry-picked from a stored commit.

**Runtime dependency:** every script sources `~/.rn-forge/shkit/current/shkit.sh`, from the external `shkit` repo. It provides logging helpers (`log_info`, `log_success`, `log_warning`, `log_notice`, `log_verbose`, `print_vars`). It is not vendored here; `install.sh` is the only place that installs it (curls shkit's own installer — not `source.sh` — or set `RNF_SHKIT_INSTALL_BUNDLE` to a local tarball path on a blocked network to skip that curl). Every other script assumes it's already present and sources it directly by absolute path — no `PATH` dependency; wiring `~/.rn-forge/bin` onto `PATH` is a separate concern owned by the shell profile.

## Code style

- 2-space indentation, LF line endings (enforced by `.editorconfig` and `shfmt`)
- `shellcheck` with SC1090/SC1091 suppressed (dynamic `source` paths — see `.shellcheckrc`)
- Scripts use `#!/bin/zsh` with `# shellcheck shell=bash` — keep new code bash-parseable (no zsh-only expansions) so shellcheck/shfmt can process it; `src/completions/_rnfmac` is the zsh-only exception, excluded from both tools
- Functions are documented with `shdoc` `# @description`/`@arg`/`@stdout`/`@exitcode` annotations (`mise run docs` renders them into `docs/`) — never hand-edit files under `docs/`, they're generated
- A file sourced (not executed) must define constants and read `$0` at the top level, never inside a function — under zsh, `readonly`/plain assignments made inside a function that's later `source`d become function-local and vanish once the function returns (`src/install.sh`'s `SELF_PATH` capture is why it sources `shkit` before defining `rnfmac_install()`, not after)
