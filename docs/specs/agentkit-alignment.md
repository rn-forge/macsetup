# Plan: adopting agentkit practices in macsetup

**Status:** implemented
**Author:** drafted 2026-08-31 from a review of `rn-forge/agentkit` at `7ca2221`
**Audience:** the implementing agent. Read [CLAUDE.md](https://github.com/rn-forge/macsetup/blob/main/CLAUDE.md) first — its
invariants section overrides anything here that contradicts it.

## Why this exists

`agentkit` is the Python sibling in the rn-forge family. It solved four problems macsetup
still has: diagnostics that are structured data rather than print statements, a consistent
flag and exit-code contract, a published documentation site, and a rule that CI may only
invoke the project's own task runner. This plan ports the parts that fit a shell codebase
and explicitly rejects the parts that don't.

Three phases, ordered by ascending risk. **Each phase is independently shippable — stop
after any one of them and the repo is in a coherent state.** Do not start a later phase
until the earlier one passes `mise run verify`.

## Ground rules for the whole plan

These are not optional and they are easy to forget:

- **Every new function carries `shdoc` annotations** (`@description`, `@arg`, `@stdout`,
  `@exitcode`, `@set`) — `mise run docs` renders them and `mise run verify` runs it.
- **Every dispatchable script keeps `${__SOURCED__:+return}` before `execute`.** That guard
  is what lets shellspec source it without running it.
- 2-space indent, LF, `#!/bin/zsh` with `# shellcheck shell=bash`, bash-parseable (no
  zsh-only expansions) so `shellcheck`/`shfmt` can process it.
- **Never index a shell array positionally** (`${arr[0]}` / `${arr[1]}`) — these scripts run
  under zsh, where arrays are 1-based, but shellcheck lints them as bash. Iterate with
  `for x in "${arr[@]}"`.
- Run `mise run verify` at the end of each phase. Do not commit or push.

---

# Phase 0 — CI runs through mise (small, do this first)

## The problem

agentkit enforces a rule via `scripts/check_ci_entrypoint.py`: **no CI step may invoke a
wrapped tool directly — only `task`.** macsetup violates this in exactly one place. In
`.github/workflows/main.yml`, the `sonar` job runs:

```yaml
- name: Run tests with coverage
  run: "$HOME/.local/bin/shellspec --kcov tests/"
```

That invocation exists only in the workflow. It cannot be reproduced locally, it is not
covered by `mise run verify`, and if the coverage flags ever need to change, the change
happens in a YAML file nobody looks at. `sonar-project.properties` depends on the
`coverage/sonarqube.xml` this step produces, so it is load-bearing.

## What to do

1. **Add the task** to [`.mise.toml`](https://github.com/rn-forge/macsetup/blob/main/.mise.toml), next to `[tasks.test]`:

   ```toml
   [tasks.test-coverage]
   description = "Run the ShellSpec suite under kcov, producing coverage/sonarqube.xml (Linux only — kcov's line tracing is a no-op on macOS)"
   run = "shellspec --kcov tests/"
   ```

   Note it is deliberately **not** added to `[tasks.verify]`'s `depends`. macOS is where
   `verify` runs and kcov reports 0% there — see the coverage invariant in CLAUDE.md.

2. **Rewrite the sonar job's steps.** It currently has no mise, so add it, and put
   shellspec on `PATH` instead of calling it by absolute path:

   - Add a `jdx/mise-action` step (copy the pinned SHA from the `verify` job — do not use a
     floating tag, the existing step pins `c37c93293d6b742fc901e1406b8f764f6fb19dac`).
   - After the ShellSpec install step, add `echo "$HOME/.local/bin" >> "$GITHUB_PATH"`.
   - Replace the coverage step's `run` with `mise run test-coverage`.
   - Keep the existing `kcov and zsh` apt step and the `ubuntu-22.04` pin and their comments.

3. **Update the docs.** Add `mise run test-coverage` to the task list in
   [README.md](https://github.com/rn-forge/macsetup/blob/main/README.md)'s Development section, with the Linux-only caveat. The
   coverage paragraph immediately below it already explains why; adjust its last sentence so
   it names the task rather than the raw `shellspec --kcov` command. Do the same for the
   coverage bullet in CLAUDE.md's Testing and CI section.

## Definition of done

`mise run test-coverage` is the only way coverage is produced, in CI and locally on Linux.
`grep -n 'shellspec\|kcov' .github/workflows/main.yml` shows only the installer step and
`mise run test-coverage`.

## Explicitly not in scope

Do **not** port `check_ci_entrypoint.py` itself. It is a Python linter enforcing a rule that,
after this phase, has exactly one workflow file and one violation class to police. The rule
is worth keeping; a linter for it is not, at this size.

---

# Phase 1 — structured doctor

## The problem

macsetup's three read-only checks ([`system/doctor.sh`](https://github.com/rn-forge/macsetup/blob/main/src/commands/system/doctor.sh),
[`profile/check.sh`](https://github.com/rn-forge/macsetup/blob/main/src/commands/profile/check.sh),
[`brew/diff.sh`](https://github.com/rn-forge/macsetup/blob/main/src/commands/brew/diff.sh)) each print as they go, via a local
`report_problem()` that is copy-pasted into two of them. Consequences:

- **Every check prints, always.** A healthy run prints ~13 green lines; a broken run prints
  the same 13 lines with two turned yellow. Failures are buried.
- **Everything is a warning.** `nvm not found` (fixable by `system init`) and
  `shkit not found` (macsetup is structurally broken) are indistinguishable.
- **Exit is binary.** 0 or 1, so no caller can distinguish "your config drifted" from "your
  machine is broken."
- **[`doctor.sh`](https://github.com/rn-forge/macsetup/blob/main/src/commands/doctor.sh) is three scripts stapled together** with
  `|| PROBLEMS=1`. There is no combined report and no summary.

agentkit's `core/doctor.py` does not
print during checking. It builds `CheckResult(status, agent, category, check, message)`
records, sorts them by `CATEGORY_ORDER × STATUS_ORDER`, and renders once. That separation is
what this phase ports.

## 1.1 The shared collector: `src/commands/lib/report.sh`

**A top-level `commands/lib/` directory is already reserved and non-dispatchable** — see
`is_lib_name()` in [`src/rnfmac.sh`](https://github.com/rn-forge/macsetup/blob/main/src/rnfmac.sh) and the matching skip in
[`src/completions/_rnfmac`](https://github.com/rn-forge/macsetup/blob/main/src/completions/_rnfmac). Creating this directory needs no
dispatcher change and adds no sub-command. (`scripts/build.sh` will `chmod +x` it along with
everything else under `commands/`; that is harmless, because the dispatcher rejects the name
`lib` explicitly *before* it checks the executable bit — that rejection exists for exactly
this case.)

Create `src/commands/lib/report.sh`. It is sourced, never executed, so it has **no shebang
line's worth of dispatch code and no `execute`**; give it the `# shellcheck shell=bash`
header and shdoc `@file`/`@brief` block like every other file.

### Critical structural constraint

Per CLAUDE.md's first invariant: **a sourced file must define its state at the top level, not
inside a function.** Under zsh, an assignment made inside a function of a sourced file can
become function-local and vanish. So:

```sh
# top level of report.sh — runs at source time, in the caller's scope
REPORT_RECORDS=()
REPORT_SEPARATOR=$'\t'
```

Do **not** write a `report_init()` that does `REPORT_RECORDS=()`. Callers source the file
once and start appending. Records are tab-separated because paths in messages routinely
contain `/`, `:` and `|`, but never tabs.

### API

| Function | Behavior |
|---|---|
| `report_add STATUS CATEGORY CHECK MESSAGE` | Appends one record. The only thing checks call. |
| `report_render` | Renders the buffer according to `RNFMAC_REPORT_FORMAT` (below) and returns nothing. |
| `report_exit_code` | Prints `0`, `1`, or `2` based on the worst status in the buffer. |
| `report_worst` | Internal: prints the worst status name. |

`report_add` appends `"${status}${REPORT_SEPARATOR}${category}${REPORT_SEPARATOR}${check}${REPORT_SEPARATOR}${message}"`.
It must not print anything.

### Output modes — `RNFMAC_REPORT_FORMAT`

`report_render` branches on the environment variable `RNFMAC_REPORT_FORMAT`:

- **`human`** (default, and the value when the variable is unset): group by category in
  `CATEGORY_ORDER`, and within each category sort by severity (`error`, `drift`, `warning`,
  `ok`). Print a category heading with `log_info`, then one line per record via the shkit
  logger matching its status: `error`→`log_error`, `drift`→`log_warning`,
  `warning`→`log_warning`, `ok`→`log_success`. Finish with a summary line
  (`log_info "N ok, N warning, N drift, N error"`). **Records with status `ok` are suppressed
  unless `RNFMAC_REPORT_ALL=1`** — this is the `--all` flag, and it is the single biggest
  readability win in this phase.
- **`json`**: emit **JSONL — one JSON object per line**, to stdout, no wrapping array.
  Fields: `status`, `group`, `category`, `check`, `message`. JSONL rather than agentkit's
  single JSON array specifically because it makes the meta-command's aggregation a `cat`
  instead of a JSON merge, and because macsetup cannot depend on `jq` being installed.
  Escape `\` and `"` in messages; paths are the only realistic source of either.
- **`raw`**: append the raw tab-separated records to the file named by `RNFMAC_REPORT_FILE`
  and print nothing. This is how the meta command collects from child processes — see 1.4.

`report_render` must also raise the log level when the format is not `human`:
`RNF_LOG_LEVEL=60` (above shkit's `CRITICAL=50`). Real shkit logs to **stderr**, so JSON on
stdout would be clean anyway, but the test double logs to **stdout**, and JSON mode must not
be corruptible by log noise in either environment. See 1.6 for the matching fixture change.

### The `group` field

`report_add` takes four arguments, but the JSON has five fields. The fifth, `group`, comes
from a top-level `REPORT_GROUP` variable each calling script sets once
(`REPORT_GROUP="system"`, `"profile"`, `"brew"`). This mirrors agentkit's `agent` field: it
is a property of the caller, not of the individual check, so it does not belong in every
call site.

## 1.2 The status taxonomy

This is the part to get right; everything else is mechanics. Four statuses, with a rule that
makes each one decidable:

| Status | Means | Example |
|---|---|---|
| `error` | **macsetup itself cannot function.** The tool is structurally broken. | `shkit` missing; `current` symlink broken; Homebrew absent |
| `drift` | **Installed state differs from configured state.** The config is the source of truth and reality disagrees. Fixable by a documented command. | stale `profile.zsh`; unpatched `.zshrc`; missing `nvm`; Brewfile drift |
| `warning` | **Advisory.** Nothing is wrong, but the user may want to know. | no host profile configured for this hostname |
| `ok` | Healthy. Hidden unless `--all`. | everything else |

Display order within a category is `error`, `drift`, `warning`, `ok` — most severe first,
matching agentkit's `STATUS_ORDER`.

### Categories (`CATEGORY_ORDER`)

`toolchain`, `runtime`, `profile`, `packages` — declared in that order at report.sh's top
level as a plain array.

### Exit-code contract

`report_exit_code` prints:

- **`0`** — no `error` and no `drift` records. Warnings alone are exit 0.
- **`2`** — one or more `drift` records, no `error`.
- **`1`** — one or more `error` records (takes precedence over drift).

**This is a deliberate behavior change.** Today every `report_problem` yields exit 1. After
this phase, a machine with drifted packages exits 2 and a machine with no host profile exits
0. That is the point: it lets a shell prompt or a launchd check distinguish "run
`profile sync`" from "macsetup is broken" from "fine." Call it out in the README.

## 1.3 Migration table — every existing call site

Replace each `log_*`/`report_problem` call with a `report_add`. Delete the local
`report_problem()` and `PROBLEMS` variable from all three scripts; the exit code now comes
from `report_exit_code`. **This table is exhaustive — if you find a call site not listed
here, the file changed since this plan was written; classify it by the 1.2 rule and note it
in the changelog at the bottom.**

### `src/commands/system/doctor.sh` (`REPORT_GROUP="system"`)

| Current line | status | category | check |
|---|---|---|---|
| `brew --version` success | `ok` | `toolchain` | `homebrew` |
| `homebrew not found` | **`error`** | `toolchain` | `homebrew` |
| oh-my-zsh plugin present / missing | `ok` / `drift` | `toolchain` | `omz-plugin` |
| `oh-my-zsh present` / not found | `ok` / `drift` | `toolchain` | `oh-my-zsh` |
| `uv --version` / not found | `ok` / `drift` | `toolchain` | `uv` |
| `nvm present` / not found | `ok` / `drift` | `toolchain` | `nvm` |
| `sdkman present` / not found | `ok` / `drift` | `toolchain` | `sdkman` |
| `macsetup current ->` / missing or broken | `ok` / **`error`** | `runtime` | `current-symlink` |
| `bin/rnfmac linked` / missing or broken | `ok` / **`error`** | `runtime` | `bin-symlink` |
| `completions/_rnfmac linked` / missing | `ok` / `drift` | `runtime` | `completions-symlink` |
| `shkit installed and sourceable` / not found | `ok` / **`error`** | `runtime` | `shkit` |
| relay patched (`log_notice`) | `ok` | `runtime` | `relay` |
| relay clean base | `ok` | `runtime` | `relay` |

Note `homebrew not found` early-returns today, skipping the plugin loop. Keep that
early return — but it must now `report_add` first, then `return`.

The relay check is informational in both branches and must stay that way: **a patched
Homebrew is not drift.** It becomes an `ok` record whose message says which state it is in,
so it only appears under `--all`. This preserves the existing "never a problem" contract while
losing the always-on `log_notice`; if you want it visible by default, that is a product
decision to raise with the user, not to make here.

### `src/commands/profile/check.sh` (`REPORT_GROUP="profile"`)

| Current line | status | category | check |
|---|---|---|---|
| `no profile for host '...'` | **`warning`** | `profile` | `host-profile` |
| `no rendered profile at ...` | `drift` | `profile` | `rendered-profile` |
| `rendered profile.zsh is stale` | `drift` | `profile` | `rendered-profile` |
| `rendered profile.zsh is up to date` | `ok` | `profile` | `rendered-profile` |
| `.zprofile is patched` / missing marker | `ok` / `drift` | `profile` | `zprofile` |
| `.zshrc is patched` / missing marker | `ok` / `drift` | `profile` | `zshrc` |

`no profile for host` becomes a **warning, not an error**: an unconfigured host is a valid
state (you have not written that host's config yet), not a broken one. `check_host_profile`
keeps its `return 1` so `execute` still skips the two dependent checks — a missing host
profile makes "is the rendered profile stale" unanswerable, not false.

### `src/commands/brew/diff.sh` (`REPORT_GROUP="brew"`)

| Current line | status | category | check |
|---|---|---|---|
| `no drift — installed packages match the Brewfile` | `ok` | `packages` | `brewfile` |
| `brew bundle check` failure (missing packages) | `drift` | `packages` | `brewfile-missing` |
| `installed but not in Brewfile:` + list | `drift` | `packages` | `brewfile-extra` |

Two wrinkles specific to this file:

- `brew bundle check --verbose` prints its own output directly to stdout, and the extras list
  is `echo`ed raw. **In `json` and `raw` formats that output must be suppressed** (redirect to
  `/dev/null`), or it will corrupt the stream. In `human` format keep it — the list of
  specific packages is the useful part. Gate it on `RNFMAC_REPORT_FORMAT`.
- `--write` short-circuits into `write_brewfile` and never reports. Leave that path alone
  entirely; it is a mutation, not a check.

## 1.4 The meta command: `src/commands/doctor.sh`

The three checks run as **separate child processes**, so they cannot share a shell array.
Collection goes through a temp file:

```
1. mktemp a records file; export RNFMAC_REPORT_FILE and RNFMAC_REPORT_FORMAT=raw
2. run system/doctor.sh, profile/check.sh, brew/diff.sh — each appends its raw records
   and renders nothing; ignore their individual exit codes (`|| true`)
3. read the file back into REPORT_RECORDS
4. unset RNFMAC_REPORT_FORMAT (or set it from this script's own --json flag)
5. report_render once
6. exit "$(report_exit_code)"
```

**Use a file, not stdout capture.** The children emit shkit log lines, and the test double
sends those to stdout (real shkit sends them to stderr) — capturing stdout would mix log
lines into the record stream in the sandbox but not in production, which is the worst
possible failure mode to debug. A named file is immune to both.

`trap 'rm -f "${RECORDS_FILE}"' EXIT` for cleanup.

The result is one report, grouped by category across all three groups, sorted by severity,
with a single summary line and one exit code — which is the entire point of the phase.

## 1.5 Flags

Add a `parse_args` to `doctor.sh`, `system/doctor.sh`, and `profile/check.sh` (modeled on the
one already in `brew/diff.sh`, which is the house style — extend that one rather than
replacing it):

| Flag | Effect |
|---|---|
| `--all` | `RNFMAC_REPORT_ALL=1` — include `ok` records in human output |
| `--json` | `RNFMAC_REPORT_FORMAT=json` |
| `-h` / `--help` / `help` | usage, exit 0 |

`--all` and `--json` together is not an error; `--all` is simply ignored in JSON mode, which
always emits every record. (agentkit rejects `--quiet`+`--json` as mutually exclusive; that
pairing does not arise here because macsetup is not gaining a `--quiet`.)

`doctor.sh` must **forward both flags to its three children** — but note that in `raw` mode
the children are already emitting everything, so it only needs to forward nothing at all and
apply the flags to its own final render. Prefer that: the parent parses, the children are
invoked in raw mode unconditionally. Simpler, and one fewer place for the flags to disagree.

Each script's `usage()` gets an shdoc block and lists its flags. `_rnfmac` completion is
positional-only (it completes sub-command names, not flags) and needs **no change**.

## 1.6 Tests

`tests/commands/doctor_spec.sh`, `tests/commands/system/doctor_spec.sh`,
`tests/commands/profile/check_spec.sh` and `tests/commands/brew/diff_spec.sh` all assert on
the exact strings this phase changes. Expect to rewrite most assertions.

**One fixture change is required.** `tests/fixtures/shkit.sh` is a test double whose `log_*`
functions print unconditionally and to **stdout**, while real shkit filters on a numeric
`RNF_LOG_LEVEL` and prints to **stderr**. JSON mode raises `RNF_LOG_LEVEL=60` to silence
logging, and the double must honor that or every JSON spec will see log lines on stdout.
Patch the double to filter numerically, defaulting to `20` (`INFO`) exactly as real shkit
does:

```sh
: "${RNF_LOG_LEVEL:=20}"
_double_log() { [ "$1" -lt "${RNF_LOG_LEVEL}" ] && return 0; shift; echo "$@"; return 0; }
log_success() { _double_log 35 "[success] $*"; }
# ...and so on, using shkit's numeric levels: verbose 15, info 20, notice 25,
# warning 30, success 35, error 40
```

The default level is unchanged, so **none of the 146 existing output assertions should move.**
If any do, that is a signal you changed a level mapping — recheck rather than editing the
assertion. Keep `log_error`'s `>&2`.

New specs to add:

- `system doctor` on a healthy toolchain: **exit 0, and the `ok` lines are absent by default**
  (this is the inverse of the current spec, which asserts they are present — that assertion
  moves to a new `--all` example).
- `system doctor --all` on a healthy toolchain: the `ok` lines are present again.
- A drift scenario (missing `nvm`): **status is 2**, not failure-generally. shellspec's
  `The status should eq 2`.
- An error scenario (`shkit` absent from the sandbox): **status is 1**.
- `doctor --json`: output is one JSON object per line, each containing `"status"` and
  `"group"`; assert that the first character of the output is `{` to prove no log noise leaked.
- `doctor` meta: one combined summary line, and category headings appear once each rather
  than three times.

## Definition of done

- `rnfmac doctor` on a healthy machine prints a category-grouped summary and little else.
- `rnfmac doctor --all` prints everything.
- `rnfmac doctor --json` prints only JSONL on stdout.
- Exit codes follow 1.2 and are covered by specs.
- `report_problem` and `PROBLEMS` appear nowhere under `src/`.
- `mise run verify` passes (which includes regenerating `docs/` from the new shdoc blocks).

---

# Phase 2 — documentation site on GitHub Pages

## The problem

`docs/` today is 100% shdoc-generated per-function reference, **checked into git**, with the
only prose being a 187-line README. The architecture — the Remote Relay design, the
`~/.rn-forge` runtime layout, the `macsetup-config` model, the invariants — lives split
between README.md and CLAUDE.md, in prose written for two different audiences, with no
canonical home. And the generated markdown is committed, so every `mise run docs` produces a
diff that reviewers must skim past.

agentkit's model, from its `docs/architecture/docs-system.md`:
**one MkDocs site is the umbrella for both handwritten prose and generated reference.** No
second site, everything in one nav, only the source of truth differs per page.

## 2.1 Toolchain

MkDocs is Python. macsetup is a shell repo with no Python toolchain — but `uv` is already a
first-class dependency (`system doctor` checks for it, `system init` installs it), so use it
with no project file at all:

```toml
[tasks.docs-site]
description = "Build the MkDocs site into site/ (strict — broken links fail the build)"
run = "uv run --with mkdocs-material mkdocs build --strict"

[tasks.docs-serve]
description = "Serve the docs site locally with live reload on http://127.0.0.1:8000"
run = "uv run --with mkdocs-material mkdocs serve"
```

`mkdocs-material` pulls in MkDocs and PyYAML, which is all 2.4's linter needs. **Do not add a
`pyproject.toml`** — this repo is not a Python project and should not start looking like one.

## 2.2 Restructure `docs/`

| Path | Source of truth | Committed? |
|---|---|---|
| `docs/index.md` | handwritten — short landing page, links into the sections | yes |
| `docs/architecture/runtime-layout.md` | handwritten — `~/.rn-forge`, versioned installs, `current` flip, atomic+locked install/upgrade | yes |
| `docs/architecture/remote-relay.md` | handwritten — the Relay design and why patches are regenerated, never cherry-picked | yes |
| `docs/architecture/config-model.md` | handwritten — the `macsetup-config` repo, shared vs host, `CONFIG_HOME` outside the versioned dir | yes |
| `docs/architecture/docs-system.md` | handwritten — this docs setup and why (see 2.5) | yes |
| `docs/guides/development.md` | handwritten — migrated from README's Development section | yes |
| `docs/guides/commands.md` | handwritten — the `rnfmac` command reference, migrated from README | yes |
| `docs/reference/**` | **generated by `mise run docs`** | **no — gitignore it** |
| `docs/specs/` | handwritten — this plan and its successors | yes |

Steps:

1. **`git rm -r --cached` the currently committed generated markdown** and move
   `mise run docs`'s output to `docs/reference/`: in `.mise.toml`'s `[tasks.docs]`, change
   `out="docs/${rel%.sh}.md"` to `out="docs/reference/${rel%.sh}.md"`. Add `docs/reference/`
   to `.gitignore` under the existing "generated artifacts" heading.
2. **Write `docs/reference/index.md`** — except it cannot be handwritten if the directory is
   gitignored. Generate it too: extend `[tasks.docs]` to emit an index page linking each
   generated file. Nav lists only `reference/index.md`; the rest are reachable by link.
   MkDocs logs pages-not-in-nav at **INFO** level, not WARNING, so `--strict` tolerates this
   — verify that with a build before relying on it.
3. **Migrate prose out of README.md, do not duplicate it.** agentkit's rule: the README is the
   front door (what it is, install, quickstart, and an index into the site); everything
   longer-form lives in the site and is *linked*. There is one copy of each explanation. The
   Homebrew Remote Relay, Machine configuration, Repository layout, and Development sections
   move; the README keeps a one-paragraph summary and a link for each.
4. **Update CLAUDE.md** to point at the new pages instead of restating them, the way
   agentkit's CLAUDE.md does. The Invariants section stays in CLAUDE.md — it is agent-facing
   guidance, not user documentation.

## 2.3 `mkdocs.yml`

Model it on agentkit's, minus the mkdocstrings plugin (no Python to document). Keep:

- **`strict: true`** — broken internal links and missing nav targets fail the build. A docs
  site that builds green while silently dropping links is worse than one that fails.
- `theme: material` with `navigation.sections`, `navigation.top`, `content.code.copy`.
- `markdown_extensions`: `admonition`, `attr_list`, `pymdownx.highlight`,
  `pymdownx.superfences`.
- `site_dir: site` and add `site/` to `.gitignore`. It **must not** be nested under `docs/`
  — MkDocs refuses that.

## 2.4 The docs linter

Port agentkit's `scripts/check-docs.py` **as-is**. It is
written as a generic template for any MkDocs site whose `nav` is the single source of page
structure, and it needs no macsetup-specific changes. It catches what `--strict` does not:
broken *relative* links, broken heading anchors, and orphan pages unreachable from nav.

Critically, its `generated_prefixes()` reads `.gitignore` for entries anchored under `docs/`
and skips them — so `docs/reference/` is auto-detected as generator output and its pages are
not required to exist at lint time. That is exactly the arrangement 2.2 creates; it works
without modification.

Wire it in:

```toml
[tasks.docs-lint]
description = "Check the docs site for broken links, bad anchors, and orphan pages"
run = "uv run --with mkdocs-material python scripts/check-docs.py ."
```

Add `docs-lint` and `docs-site` to `[tasks.verify]`'s `depends`, after `docs` (the generated
reference must exist before the site builds).

## 2.5 The design record

Write `docs/architecture/docs-system.md` following agentkit's page: what is handwritten vs
generated, why one site rather than two, why `strict: true`, what the linter adds over
strict, the relationship to the README ("one copy of each explanation"), and a dated
changelog entry. Link it from CLAUDE.md with the instruction *update it when the docs tooling
changes*. This is the part that keeps the setup from rotting once the person who built it has
moved on.

## 2.6 The Pages workflow

New file `.github/workflows/docs.yml`, modeled on agentkit's workflow of the same name:

- Triggers: `push` to `main`, plus `workflow_dispatch`.
- `permissions: contents: read, pages: write, id-token: write`.
- `concurrency: group: pages, cancel-in-progress: false`.
- Two jobs: `build` (checkout → mise-action → `mise run docs` → `mise run docs-site` →
  `actions/upload-pages-artifact@v4` pointing at `site/`) and `deploy`
  (`actions/deploy-pages@v4` with the `github-pages` environment).
- `mise run docs` needs `gawk` — the `verify` job installs it via brew on macOS; on
  `ubuntu-latest` use `sudo apt-get install -y gawk`. Alternatively run this workflow on
  `macos-latest` for consistency with `verify`; ubuntu is faster and cheaper, prefer it.
- **Pin every third-party action to a SHA**, matching the existing workflow's convention.

Keep this as a **separate workflow from `main.yml`**. Docs deployment and the CI gate have
different triggers, different permissions, and different failure consequences; agentkit
separates them for the same reason.

### One manual step this cannot do

**GitHub Pages must be enabled in repo settings with Source: GitHub Actions.** No workflow can
set that. Say so in a comment at the top of `docs.yml` (agentkit's does) and tell the user
when you hand the phase back — the first run will fail confusingly otherwise.

## Definition of done

- `mise run docs-site` builds clean under `--strict`; `mise run docs-lint` passes.
- `mise run verify` includes both.
- No generated markdown is tracked by git.
- README is front-door-sized; every long-form explanation exists exactly once, in the site.
- `docs/architecture/docs-system.md` exists and is linked from CLAUDE.md.
- The user has been told to flip on Pages.

---

# Explicitly rejected — do not implement

These were evaluated against agentkit and deliberately left out. If a future session thinks
one of them is an obvious gap, it is not; it was considered.

- **The wrapper/inner task split.** agentkit splits `Taskfile.yml` (wrappers only) from
  `tasks/*.yml` (`internal: true` primitives), enforced by `check_task_layout.py`. macsetup
  has ~11 mise tasks in one flat file. Two layers plus a linter for that is ceremony with no
  reader to serve. Phase 0 takes the one rule from that system that pays for itself.
- **Rich-style rendered tables.** agentkit uses `rich.Table` and markup. There is no
  equivalent for zsh, and hand-rolled box-drawing in AWK is a maintenance liability for
  cosmetic gain. Phase 1's category grouping and summary line capture the actual benefit —
  which was structure, not the library.
- **A state/hash store with backups.** agentkit's `core/state.py` hashes every managed
  artifact and snapshots natives before overwriting, because it writes many files it does not
  own. macsetup writes one rendered `profile.zsh` and patches two rc files, and
  `profile/check.sh` already does render-and-diff — the right-sized version of the same idea.
  `profile/sync.sh` already backs up.
- **`--quiet`.** agentkit needs it because it is scriptable in pipelines. macsetup's logs go
  to stderr already, so `2>/dev/null` is the shell-native answer.

# Deferred — raise with the user, do not decide alone

- **`--dry-run` on `system sync` and `profile sync`.** agentkit shows a unified diff before
  writing on every mutating command, and macsetup has no `--dry-run` anywhere (verified:
  `grep -rn -- '--dry-run' src/` is empty). `profile/check.sh` is already half of this — it
  renders to a temp file and diffs. But `system sync` drives real installers with no
  mockable seam, so a truthful dry-run there is a much larger job than it looks. Worth doing,
  worth scoping separately.
- **Whether the relay-state line should stay visible by default.** Phase 1 demotes it to an
  `ok` record, hiding it unless `--all`. That is a product call.

# Changelog

- 2026-08-31: initial plan, from a review of agentkit at `7ca2221`.
- 2026-08-31: implemented all three phases; converted repository-relative source links to GitHub links so the specification builds cleanly inside the strict MkDocs site.
