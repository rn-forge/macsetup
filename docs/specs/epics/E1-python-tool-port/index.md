# E1 — Port rnfmac to a kiln python-tool

|  |  |
| -- | -- |
| **State** | Active |
| **Start Date** | 2026-11-21 |

<!-- BEGIN derived features -->

| Feature | State | Iteration | Stories |
| -- | -- | -- | -- |
| [F1.1 — Phase 0: source the rn-forge home's env.sh](F1.1-home-env-sh.md) | Active | release-1 | 1 Active · 1 Closed |
| [F1.2 — Phase 1: kiln scaffold beside the shell product](F1.2-kiln-scaffold.md) | Closed | release-1 | 2 Closed |
| [F1.3 — Phase 2: port the read-only commands](F1.3-read-only-commands.md) | Closed | release-1 | 5 Closed |
| [F1.4 — Phase 3: port the commands that change the machine](F1.4-machine-changing-commands.md) | Active | release-1 | 6 Closed |
| [F1.5 — Phase 4: cutover](F1.5-cutover.md) | Active | release-1 | 1 New · 2 Closed |

<!-- END derived features -->

Rebuild `rnfmac` as the kiln `python-tool` `rn-forge-macsetup`, beside the shell
product, one phase at a time, then cut over: the bootstrap stays shell,
everything else becomes Python under `task`, and the lifecycle commands come
from `rn-forge-tooling`. The configuration contract (`macsetup-config`, the
`config/` checkout, the rendered `profile.zsh`) does not change. The design, its
decisions and each phase's steps are in
[the port plan](../../python-tool-port.md); each feature here is one phase.
