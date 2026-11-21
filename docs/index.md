# macsetup

macsetup is a macOS system-configuration toolkit driven by one CLI, `rnfmac`:
one-time machine bootstrap, idempotent day-to-day synchronization, and a
Homebrew Remote Relay for networks that block package downloads. It is being
ported from shell to a Python tool ([the plan](specs/python-tool-port.md)); the
shell `rnfmac` is still what ships.

- [Architecture](architecture/index.md) — how the repo is put together.
- [Guides](guides/index.md) — how to use `rnfmac` and how to work in the repo.
- [Runbooks](runbooks/index.md) — procedures that need judgement.
- [Reference](reference/python-api.md) — the generated Python API.
- [Releases](releases/index.md) — what shipped when.
- [Specs](specs/index.md) — work planned and done.
- [Decisions](adr/index.md) — the ADR log.

The repository standard this tree obeys is rendered into
`.rn-forge/kiln/standard.md` by kiln; the reasoning behind it lives in the kiln
repo's own decision log.
