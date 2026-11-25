# Commands

## Install

Install on a fresh machine:

```sh
. <(curl -fsSL https://raw.githubusercontent.com/rn-forge/macsetup/main/bootstrap.sh)
```

`bootstrap.sh` installs Homebrew and uv when missing, then runs
`rnfmac self install`. Pass `--force` to reinstall:

```sh
. ./bootstrap.sh --force
```

On a blocked network, copy `bootstrap.sh` and a release archive across, then
install from the archive, naming its version:

```sh
. ./bootstrap.sh --archive ~/Downloads/macsetup.tar.gz --version 3.0.0
```

Installation creates the
[versioned runtime layout](../architecture/runtime-layout.md) and exposes
`rnfmac` in the current shell. It does not apply machine configuration.

## Bootstrap and synchronize

Run the bootstrap once as a local administrator:

```sh
rnfmac system init
rnfmac system init --force  # reinstall or reconfigure every component
```

It installs Homebrew, the Homebrew Remote Relay, oh-my-zsh and plugins, uv, nvm,
and SDKMAN in that order, skipping components already present unless `--force`
is set.

Then synchronize whenever configuration changes:

```sh
rnfmac sync
```

Sync runs these steps in order:

1. `rnfmac config pull` fast-forwards configuration. If it had to clone the
   checkout, sync stops so you can inspect it before applying anything.
1. `rnfmac profile sync` renders shared and host profiles, patches `.zprofile`
   and `.zshrc`, and installs the bundled theme and keybindings.
1. `rnfmac brew sync` installs and removes packages to match the host Brewfile.
1. `rnfmac system sync` installs configured Python, Node.js, and Java versions.
   Unresolved or failed versions are skipped while the remaining versions
   continue; the command exits nonzero after all attempts if any were skipped.

See the [configuration model](../architecture/config-model.md) for merge and
update behavior.

## Health and drift

```sh
rnfmac doctor
rnfmac doctor --all
rnfmac doctor --json
rnfmac system doctor
rnfmac profile check
rnfmac brew diff
rnfmac brew diff --write
```

`rnfmac doctor` combines toolchain, runtime-layout, profile, and package checks
into one category-grouped report. Healthy records are hidden by default; `--all`
includes them and `--json` emits every record as JSONL. The same reporting flags
are available on `system doctor`, `profile check`, and `brew diff`.

Doctor-style checks use these exit codes:

| Code | Meaning |
| -- | -- |
| `0` | Healthy or advisory warnings only. |
| `2` | Installed state has drifted from configured state. |
| `1` | macsetup itself is structurally broken. |

`brew diff --write` is a mutation rather than a report: it rewrites the current
host's Brewfile from installed packages.

## Configuration

```sh
rnfmac config status
rnfmac config pull
rnfmac config push --message "Update host config"
rnfmac config reset --force
```

- `status` shows the branch, revision, upstream state, and local changes.
- `pull` clones when absent or fast-forwards `origin/main`, carrying uncommitted
  changes across on a stash.
- `push` commits local changes with the required message and publishes them.
- `reset --force` discards local changes and resets to `origin/main`; it refuses
  to discard anything without `--force`.

## The rnfmac self lifecycle

```sh
rnfmac self install
rnfmac self upgrade
rnfmac self uninstall
rnfmac self cleanup
rnfmac self status
rnfmac self doctor
```

These verbs come from `rn-forge-tooling`: `install` and `upgrade` manage the
versioned installation, `cleanup` removes every installed version except the
target of `current`, `uninstall` removes the product directory, and `status` and
`doctor` report on the installation. An upgrade never applies configuration; run
`rnfmac sync` after reviewing it.

## Homebrew Remote Relay

```sh
rnfmac brew relay
rnfmac brew relay --force
rnfmac brew relay --reset
rnfmac brew relay --regen
```

See [Homebrew Remote Relay](../architecture/remote-relay.md) for its design,
environment variables, and patch-authoring workflow.

Run `rnfmac --help` to list the commands and groups.
