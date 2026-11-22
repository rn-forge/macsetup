# Release 1 — Python rnfmac

|  |  |
| -- | -- |
| **Status** | in progress |
| **Start Date** | 2026-11-21 |

The first release in which `rnfmac` is the kiln `python-tool` rather than the
shell product: every command ported, the bootstrap in place of `install.sh`, and
the shell payload retired.

## Entry criteria

- `rn-forge-tooling` 0.4.0 or later is available, so installs write `env.sh` and
  link the Typer completion.

## Scope

<!-- BEGIN derived scope -->

| Feature | Epic | State |
| -- | -- | -- |
| [F1.1 — Phase 0: source the rn-forge home's env.sh](../../specs/epics/E1-python-tool-port/F1.1-home-env-sh.md) | E1 | Active |
| [F1.2 — Phase 1: kiln scaffold beside the shell product](../../specs/epics/E1-python-tool-port/F1.2-kiln-scaffold.md) | E1 | Closed |
| [F1.3 — Phase 2: port the read-only commands](../../specs/epics/E1-python-tool-port/F1.3-read-only-commands.md) | E1 | Closed |
| [F1.4 — Phase 3: port the commands that change the machine](../../specs/epics/E1-python-tool-port/F1.4-machine-changing-commands.md) | E1 | Active |
| [F1.5 — Phase 4: cutover](../../specs/epics/E1-python-tool-port/F1.5-cutover.md) | E1 | New |

<!-- END derived scope -->

## Decisions

- None yet. The port's decisions are recorded in
  [the port plan](../../specs/python-tool-port.md#decisions-taken).

## Breaking changes

- `rnfmac upgrade`, `cleanup` and `version` are replaced by the `self` group in
  Phase 4. Each host is migrated once (F1.5).

## Progress

Phases 0–2 are done apart from publishing the Phase 0 profile change. Phase 3
(F1.4) is being built story by story; Phase 4 (F1.5) follows it.

## Commits

```bash
git log --oneline -E --grep='S1\.|F1\.|E1|Phase [0-4]'
```

## Exit criteria

- Every feature of E1 is closed.
- No Dependabot pull request is open against the default branch, or each open
  one is listed here as deferred, with its reason.

## Shipped

| Deliverable | Version | Tag | Commit | Verification |
| -- | -- | -- | -- | -- |
