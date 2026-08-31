# macsetup

`macsetup` is a macOS system-configuration toolkit driven by one CLI, `rnfmac`. It provides a one-time machine bootstrap, idempotent day-to-day synchronization, and a Homebrew Remote Relay for networks that block package downloads.

It manages Homebrew packages, shell configuration, Python via uv, Node.js via nvm, Java via SDKMAN, macOS keybindings, and per-machine configuration stored outside the release payload.

## Start here

- [Install and use `rnfmac`](guides/commands.md)
- [Set up a development checkout](guides/development.md)
- [Understand the runtime layout](architecture/runtime-layout.md)
- [Configure shared and host-specific state](architecture/config-model.md)
- [Use the Homebrew Remote Relay](architecture/remote-relay.md)
- [Understand how this documentation is maintained](architecture/docs-system.md)
- [Browse generated shell API reference](reference/index.md)

