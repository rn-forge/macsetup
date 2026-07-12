# macsetup

**macsetup** — a macOS system configuration toolkit driven by one CLI, `rnfmac`: one-time machine bootstrap, idempotent day-to-day sync, and a Homebrew "Remote Relay" that routes package downloads through a trusted remote host when the local network blocks them.

Pure shell/Ruby/AWK — no build system beyond [`mise`](https://mise.jdx.dev) for formatting, linting, and packaging the release tarball.

## What it does

| Concern | How it's handled |
| --- | --- |
| Package manager | Homebrew, with per-machine `Brewfile`s (`brew bundle install` + `cleanup`) |
| Shell | oh-my-zsh + `zsh-completions`, `zsh-autosuggestions`, `zsh-syntax-highlighting`, custom theme |
| Python | [uv](https://docs.astral.sh/uv/) (pinned to Python 3.15) |
| Node.js | [nvm](https://github.com/nvm-sh/nvm) (latest LTS) |
| Java | [SDKMAN](https://sdkman.io) (Temurin 21) |
| Dotfiles | Rendered profile + rc-file patches, symlinked into `~/.rn-forge/` |
| macOS keybindings | `DefaultKeyBinding.dict` copied into `~/Library/KeyBindings/` |
| Restricted networks | Homebrew Remote Relay (SSH-proxied downloads) |

## Quick start

### 1. Install `rnfmac`

From a fresh machine (no local checkout needed):

```sh
. <(curl -fsSL https://github.com/rn-forge/macsetup/releases/latest/download/install.sh)
```

From a git checkout or unpacked release dist:

```sh
. src/install.sh
```

Either way this installs into `~/.rn-forge/macsetup/<version>/`, symlinks `current`, links `rnfmac` + its zsh completion into `~/.rn-forge/bin` / `~/.rn-forge/completions`, and exports `PATH` for the current shell. Add the `PATH` export to `~/.zprofile` to persist it. It does **not** touch shell rc files or install anything else — that's the next two steps.

### 2. Bootstrap a brand-new Mac (run once, as local admin)

```sh
rnfmac system init          # add --force to reinstall everything
```

Installs, in order: Homebrew → Homebrew Remote Relay → oh-my-zsh (+ plugins) → uv → nvm → SDKMAN. Each step is skipped if already present (unless `--force`).

### 3. Sync (run anytime, idempotent)

```sh
rnfmac sync
```

Composes three steps, in order:

1. **`rnfmac profile sync`** — renders shared + host `profile.zsh` into `~/.rn-forge/macsetup/profile.zsh`, patches `.zprofile`/`.zshrc` to source it (existing rc files are backed up first), installs the custom zsh theme and macOS keybindings.
2. **`rnfmac brew sync`** — `brew bundle install` and `brew bundle cleanup` against the machine's `Brewfile`, so the installed set exactly matches the profile.
3. **`rnfmac system sync`** — installs the pinned runtimes: Python 3.15 (uv), Node LTS (nvm), Java 21 Temurin (SDKMAN).

### Other commands

```sh
rnfmac doctor           # read-only health sweep across system/profile/brew — exit 1 if anything's drifted
rnfmac version          # print the installed version
rnfmac upgrade          # fetch and install the latest GitHub release, flip `current`
rnfmac cleanup          # delete every installed version except the one `current` points to
rnfmac system doctor    # read-only toolchain health check (Homebrew, oh-my-zsh, uv, nvm, SDKMAN presence)
rnfmac profile check    # does the installed profile match what sync would render?
rnfmac brew diff        # drift between installed packages and the Brewfile (--write to update it)
rnfmac brew relay       # (re)apply the Homebrew Remote Relay patches
rnfmac --help           # list all sub-commands and groups
```

## Machine profiles

Each machine gets a directory under `src/profiles/` named after its lowercased short hostname (`hostname | cut -d. -f1`):

```text
src/profiles/
├── shared/                 # common to all machines
│   ├── profile.zsh         #   shell env: homebrew, oh-my-zsh, uv, nvm, sdkman
│   ├── rohitnarayanan.zsh-theme
│   └── DefaultKeyBinding.dict
├── rohitmacbook/           # one directory per machine
│   ├── profile.zsh         #   machine-specific env vars / overrides
│   └── Brewfile            #   machine-specific package set
├── rohitmacmini/
├── 02hw067696/
└── rpu-rnaray-3m2c/
```

At sync time, shared `profile.zsh` is rendered first, then the machine's — host settings win by coming last, all concatenated into one file that `rnfmac profile sync` sources from the shell rc.

**To add a new machine:** create `src/profiles/<hostname>/` with a `profile.zsh` and a `Brewfile`, then run `rnfmac sync` on that machine.

## Homebrew Remote Relay

Corporate networks (e.g. behind Zscaler) often block the CDNs Homebrew downloads from. The Remote Relay works around this by delegating the download to a remote host that *does* have access:

```text
local mac ──ssh──▶ relay host ──curl──▶ ghcr.io / CDN
    ◀───────scp────── downloaded artifact
```

When `HOMEBREW_REMOTE_RELAY_ENABLED=1`, a custom `RemoteRelayCurlDownloadStrategy` replaces Homebrew's default curl strategy: it SSHes to `HOMEBREW_REMOTE_RELAY_HOST`, runs the `curl` there, SCPs the artifact back into the local Homebrew cache, and cleans up the remote temp file.

`rnfmac brew relay` applies the payload from `src/homebrew/` (a mirror of Homebrew's internal layout) into the local Homebrew install at `/opt/homebrew` (Apple Silicon only): it resets Homebrew to clean and re-applies the patches fresh every time, rather than cherry-picking a stored commit.

- `src/homebrew/patches/` — patches for `download_strategy.rb`, `download_strategy_detector.rb`, and `cmd/vendor-install.sh` (so vendored downloads also go through the relay)
- `src/homebrew/download_strategy/remote_relay_curl_download_strategy.rb` — the new strategy class

Configuration (set in `src/profiles/shared/profile.zsh`):

| Variable | Default | Purpose |
| --- | --- | --- |
| `HOMEBREW_REMOTE_RELAY_ENABLED` | `0` | Turn the relay on/off |
| `HOMEBREW_REMOTE_RELAY_HOST` | `rohitnarayanan@rohitmacmini.local` | SSH target that performs downloads |
| `HOMEBREW_REMOTE_RELAY_DEBUG` | `1` | Print the relay commands being run |

> **Note:** a Homebrew upgrade can overwrite the staged files — rerun `rnfmac brew relay` afterwards.

## Repository layout

```text
src/
├── rnfmac.sh                        # dispatcher: rnfmac <sub-command> [<sub-command>] [args]
├── install.sh                       # standalone installer (sourced), also a release asset
├── commands/
│   ├── sync.sh                      # composes profile sync -> brew sync -> system sync
│   ├── doctor.sh                    # read-only sweep across all groups
│   ├── version.sh
│   ├── upgrade.sh
│   ├── cleanup.sh                   # deletes old versions, keeps `current`
│   ├── system/                      # init.sh (bootstrap), sync.sh (runtimes), doctor.sh
│   ├── profile/                     # sync.sh, check.sh, lib.sh (shared helpers)
│   └── brew/                        # sync.sh, diff.sh, relay.sh
├── completions/_rnfmac              # zsh completion, enumerates commands/ at runtime
├── homebrew/                        # Remote Relay patches + strategy class
└── profiles/
    ├── shared/                      # common shell config, theme, keybindings
    └── <hostname>/                  # per-machine profile.zsh + Brewfile
```

`~/.rn-forge` (`RNF_HOME`) is the shared home for the rn-forge product family: each product installs to `~/.rn-forge/<product>/<version>/` with a `current` symlink, plus one symlink per product under `~/.rn-forge/bin/` and `~/.rn-forge/completions/`. Upgrade/rollback is just flipping `current`.

**Runtime dependency:** every script sources `~/.rn-forge/shkit/current/shkit.sh`, a small shell library from the external [`shkit`](https://github.com/rn-forge/shkit) repo (logging helpers, `print_vars`). `install.sh` is the only place that installs it; every other script assumes it's already present.

## Development

Tooling is pinned via [`.mise.toml`](.mise.toml) (`shellcheck 0.11.0`, `shfmt 3.13.1`):

```sh
mise run format        # format shell scripts with shfmt (in-place)
mise run format-check  # dry-run format check (CI)
mise run lint          # shellcheck all shell scripts
mise run test          # run the shellspec suite (tests/)
mise run docs          # regenerate docs/ from shdoc annotations in src/ — never hand-edit docs/
mise run build         # stage dist/macsetup and build the release tarball
mise run verify        # format-check + lint + test + build + docs (full CI gate)
mise run clean         # remove dist/
```

`tests/` holds a [`shellspec`](https://github.com/shellspec/shellspec) suite covering install, upgrade, cleanup, sync, and the profile/brew/relay commands, each run against a sandboxed `$HOME` (see `tests/spec_helper.sh`). `system/init.sh` and `system/sync.sh` are untested by design — they drive real Homebrew/oh-my-zsh/uv/nvm/SDKMAN installers with no mockable seam, so that surface gets manual verification instead. `shellspec` isn't in `.mise.toml`'s tool pins (no mise plugin for it); install it separately, or let CI curl it.

No code-coverage gate: `kcov`'s bash/zsh line-tracing doesn't actually work on macOS (it runs and reports 0% covered on scripts that visibly executed), so this repo doesn't attempt one.

Code style: 2-space indent, LF line endings (enforced by `.editorconfig` and `shfmt`); scripts use `#!/bin/zsh` with `# shellcheck shell=bash` (kept bash-parseable so shellcheck/shfmt can process it); shellcheck runs with SC1090/SC1091 suppressed for dynamic `source` paths (see `.shellcheckrc`).
