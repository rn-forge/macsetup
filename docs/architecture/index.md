# Architecture

How macsetup is put together.

- [Runtime layout](runtime-layout.md) — versioned installs, stable symlinks and
  atomic upgrades under `$RNF_HOME`.
- [Configuration model](config-model.md) — shared and host-specific profiles,
  Brewfiles, runtime versions, and the persistent `macsetup-config` checkout.
- [Homebrew Remote Relay](remote-relay.md) — restricted-network downloads and
  patch maintenance.
- [Documentation system](docs-system.md) — what is handwritten, what is
  generated, and how the site is validated and published.
