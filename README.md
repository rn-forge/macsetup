# macsetup

**macsetup** is a macOS system-configuration toolkit driven by one CLI, `rnfmac`: one-time machine bootstrap, idempotent day-to-day synchronization, and a Homebrew Remote Relay for networks that block package downloads.

It manages Homebrew packages, oh-my-zsh, Python with uv, Node.js with nvm, Java with SDKMAN, shell profiles, and macOS keybindings. Machine-specific state lives in a separate configuration repository, outside versioned releases.

## Install

On a fresh machine:

```sh
. <(curl -fsSL https://github.com/rn-forge/macsetup/releases/latest/download/install.sh)
```

From a checkout, use `. src/install.sh`. On a blocked network, use `. install.sh --archive ~/Downloads/macsetup.tar.gz` with a release archive already on disk.

## Quick start

```sh
rnfmac system init  # one-time bootstrap; run as a local administrator
rnfmac sync         # pull and apply machine configuration
rnfmac doctor       # report toolchain, profile, and package health
```

The first sync after a missing configuration checkout only clones it and stops. Review the checkout, then run `rnfmac sync` again to apply it.

## Documentation

- [Commands](docs/guides/commands.md): installation options, bootstrap and sync behavior, health-report exit codes, configuration, upgrades, and cleanup.
- [Configuration model](docs/architecture/config-model.md): shared and host-specific profiles, Brewfiles, runtime versions, and the persistent `macsetup-config` checkout.
- [Runtime layout](docs/architecture/runtime-layout.md): versioned installations, stable symlinks, atomic upgrades, and the external shkit dependency.
- [Homebrew Remote Relay](docs/architecture/remote-relay.md): restricted-network downloads, configuration variables, and patch maintenance.
- [Development](docs/guides/development.md): repository tasks, tests, coverage, code style, and documentation generation.
- [Documentation system](docs/architecture/docs-system.md): handwritten versus generated content, validation, and publishing.
