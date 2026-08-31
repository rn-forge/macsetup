# Runtime layout

## Product home

`~/.rn-forge` (`RNF_HOME`) is the shared runtime home for the rn-forge product family. Each product uses versioned installations and a stable `current` symlink:

```text
~/.rn-forge/
├── bin/
│   └── rnfmac -> ../macsetup/current/rnfmac.sh
├── completions/
│   └── _rnfmac -> ../macsetup/current/completions/_rnfmac
├── macsetup/
│   ├── current -> vX.Y.Z
│   ├── vX.Y.Z/
│   ├── vA.B.C/
│   ├── config/
│   └── profile.zsh
└── shkit/
    └── current/
        └── shkit.sh
```

Installing, upgrading, or rolling back changes which version `current` points to. Stable symlinks under `bin/` and `completions/` continue to resolve through it. `rnfmac cleanup` removes every installed macsetup version except the target of `current`.

The persistent `config/` checkout and rendered `profile.zsh` are deliberately outside every version directory. Changing the installed release therefore never overwrites machine configuration.

## Installation and upgrade

`src/install.sh` is sourceable and is also published as a standalone release asset. It can install from the current checkout, a release distribution beside the script, the latest GitHub release, or a local archive supplied with `--archive`. `rnfmac upgrade` uses the same release layout and accepts the same local-archive mode.

Both paths stage a complete distribution in a scratch directory, acquire a portable `mkdir`-based lock, and atomically replace the target version directory before flipping `current`. Concurrent installs or upgrades are serialized. A downloaded or local archive is checked against its sibling `.sha256` file when available; a missing checksum produces a warning rather than blocking installation.

An upgrade pulls the persistent configuration checkout after moving `current`, but never applies that configuration. Run `rnfmac sync` separately after reviewing it. A local archive can intentionally move to an older build.

## Runtime dependency

Every installed command sources `~/.rn-forge/shkit/current/shkit.sh` by absolute path. `shkit` supplies logging and diagnostic helpers and is not vendored into macsetup. The installer is the only component that installs it, either through shkit's installer or from `RNF_SHKIT_INSTALL_BUNDLE` on a blocked network. Shell-profile configuration owns adding `~/.rn-forge/bin` to `PATH`.

## Distribution payload

Everything under `src/` is shipped. `scripts/build.sh` stages that tree into `dist/` and creates the release archive.

```text
src/
├── rnfmac.sh               # dynamic command dispatcher
├── install.sh              # sourceable installer and release asset
├── commands/               # top-level and grouped rnfmac commands
├── completions/_rnfmac     # dynamic zsh command completion
├── homebrew/               # Remote Relay patches and strategy
└── profiles/shared/        # bundled theme and keybindings
```

The dispatcher maps `rnfmac <command>` to `commands/<command>.sh` and `rnfmac <group> <command>` to `commands/<group>/<command>.sh`. Adding a dispatchable script automatically adds its command and completion; a group-level `lib.sh` and the top-level `commands/lib/` directory are helper code, not commands.

