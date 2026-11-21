# Plan: macsetup becomes a kiln `python-tool`

**Status:** planned (2026-11-21)
**Audience:** the implementing agent. Read [CLAUDE.md](https://github.com/rn-forge/macsetup/blob/main/CLAUDE.md) first.
Its invariants section overrides anything here that contradicts it, except where
a phase below retires the code that invariant describes.

## Why this exists

macsetup was written in shell, before kiln existed, so that it had no
prerequisites on a fresh Mac: it is what installs the toolchain the rest of the
rn-forge stack needs. The owner has since separated two concerns. **Bootstrapping
a fresh machine** has to stay prerequisite-free. **Developing macsetup** does not,
and should follow the same kiln standard as every other rn-forge repository.

Only the bootstrap needs shell. Everything else in macsetup is either:

- **lifecycle code that `rn-forge-tooling` already provides**: `install.sh`,
  `upgrade`, `cleanup` and `version` hand-roll versioned installs under
  `$RNF_HOME`, the `current` link, the lock, archive installs and checksums.
  A `python-tool` gets `self install/upgrade/uninstall/cleanup/status/doctor`
  for free, the same way kiln does; or
- **subprocess orchestration and file rendering**: `brew bundle`, `git`,
  `curl | sh` installers, `defaults`, and rendering `profile.zsh`. All of this
  ports to Python directly. The dispatcher already runs every command as a
  subprocess (`exec`), and no command sources anything into the caller's shell.

The port also removes the shkit runtime dependency, because `rn-forge-commons`
and `rn-forge-cli` cover logging and the doctor report. And it fixes coverage:
kcov's line tracing does nothing on macOS, so today coverage exists only in a
Linux CI job. pytest coverage works on the Mac.

## Decisions taken

- **Archetype:** `python-tool` (`python-app` with `lifecycle = true`), docs
  profile `mkdocs`, CI on GitHub Actions with Sonar on, the same as kiln.
- **Names:** the distribution is `rn-forge-macsetup`, the import package is
  `rn_forge.macsetup` and the command stays **`rnfmac`**. The `ToolProduct` is
  `name="macsetup"`, `repo="rn-forge/macsetup"`, with links
  `bin/rnfmac` and `completions/_rnfmac`.
- **Install sources.** On the restricted network, only downloads from
  `*.githubusercontent.com` were blocked. A tooling install never touches that
  host. It downloads GitHub's generated source tarball from `github.com` (tag
  or commit), then runs `uv tool install` on it, and uv resolves dependencies
  from PyPI. Where even that fails, `rnfmac self install --archive <file>`
  installs from a file on disk, which tooling already supports. Both sources
  cover today's `install.sh` streaming and `--archive` modes, so no wheelhouse
  is needed. A PyPI release of `rn-forge-macsetup` is *not* required: kiln's
  PyPI release job is `python-lib`-only, and nothing here depends on it.
- **uv comes from Homebrew**, as it does today (`system init` → `brew install
  uv`). The bootstrap installs Homebrew, then uv, then `rnfmac`. Do not add the
  standalone uv installer: it downloads from GitHub release assets, which
  redirect to `githubusercontent.com`, and it would leave the machine with two
  uv installations.
- **The configuration contract does not change.** The `macsetup-config` layout
  (`shared/`, `hosts/<host>/`, Brewfiles, `<runtime>-versions`, `profile.zsh`),
  the persistent `$RNF_HOME/macsetup/config/` checkout and the rendered
  `$RNF_HOME/macsetup/profile.zsh` stay exactly as they are. A host sees no
  difference after the port except where `rnfmac` comes from.
- **Assets ship as package data**, unchanged: the zsh theme,
  `DefaultKeyBinding.dict`, the Homebrew Remote Relay patches and
  `remote_relay_curl_download_strategy.rb`.
- **`_rnfmac` becomes Typer's completion**, which tooling links at
  `completions/_rnfmac` (pykit F28.1, `rn-forge-tooling` 0.4.0). The
  hand-written completion is deleted.

Phases are ordered by risk. **Each one ships on its own; stop after any phase
and the repo is coherent.** Phase 0 is shell work that lands before the port
and is valid whether or not the port ever happens.

---

# Phase 0 — macsetup sources the rn-forge home's `env.sh`

`$RNF_HOME` is now a written contract, owned by pykit
([ADR-0017](https://github.com/rn-forge/pykit/blob/main/docs/adr/ADR-0017.md),
published as `rn-forge-tooling`'s guide
[The rn-forge home](https://github.com/rn-forge/pykit/blob/main/packages/rn-forge-tooling/docs/guides/home.md),
shipping with pykit Release 11). The home owns
`$RNF_HOME/env.sh`, which puts `bin/` on `PATH` and `completions/` on `fpath`.
shkit's `install.sh` writes it, and macsetup always runs that installer first
(shkit's `docs/specs/rn-forge-home.md`).

Today macsetup restates those lines itself: `macsetup-config`'s
`shared/profile.zsh` exports `RNF_HOME`, prepends `bin/` to `PATH` and appends
`completions/` to `fpath`. Once `env.sh` exists, the profile should source it
and drop its own copies, so that the profile and every other installer use the
same lines.

**Depends on:** the shkit release that writes `env.sh`. Land the config change
only after that release is installed on every host. The guard below keeps the
profile safe before then.

## What to do

1. **`macsetup-config`, `shared/profile.zsh`.** Replace the "rn-forge home"
   block:

    ```sh
    export RNF_HOME="${HOME}/.rn-forge"
    export PATH="${RNF_HOME}/bin:${PATH}"
    ```

    with:

    ```sh
    if [ -f "${HOME}/.rn-forge/env.sh" ]; then
      source "${HOME}/.rn-forge/env.sh"
    else
      export RNF_HOME="${HOME}/.rn-forge"
      export PATH="${RNF_HOME}/bin:${PATH}"
      fpath+=${RNF_HOME}/completions
    fi
    ```

    Then delete `fpath+=${RNF_HOME}/completions` from the oh-my-zsh block. The
    block stays above `compinit`, which is where the contract asks for it.
    Publish with `rnfmac config push`.

2. **macsetup, `docs/architecture/runtime-layout.md`.** Add `env.sh` to the
   layout tree. Replace "Shell-profile configuration owns adding
   `~/.rn-forge/bin` to `PATH`" with: the home's `env.sh` does that, shkit's
   installer writes it, and the rendered profile sources it. Link the contract
   page as the normative layout. Keep only what is macsetup's own:
   `macsetup/<version>/`, `config/` and `profile.zsh`.

3. **`src/install.sh` honours `$RNF_HOME`.** The contract's location is
   `$RNF_HOME`, or `~/.rn-forge` when that is unset or empty; line 29 sets
   `RNF_HOME="${HOME}/.rn-forge"` unconditionally. Make it
   `RNF_HOME="${RNF_HOME:-${HOME}/.rn-forge}"` and pass it through to shkit's
   installer, so both write the same home. The profile keeps `~/.rn-forge`:
   it is this owner's personal configuration, and `env.sh` re-exports
   `RNF_HOME` with the home's absolute path anyway. Otherwise no change: the
   installer already creates `completions/` and links `_rnfmac`, which the
   contract allows, and it gets `env.sh` from shkit's installer, which it runs
   first. `_rnfmac` is hand-written, so pykit's Typer-specific completion
   handling does not apply to it until Phase 3.

## Validation

- On a host: `rnfmac sync`, open a new zsh, and check that `echo $fpath` lists
  `~/.rn-forge/completions` once, `rnfmac <TAB>` completes, and `rnfshk` is on
  `PATH`. `env.sh` puts `completions/` first on `fpath`, where the fallback
  appended it; either order works for `compinit`.
- After installing a Python tool with `rn-forge-tooling` 0.4.0 or later (kiln,
  for example), `kiln <TAB>` completes in a new zsh, with no change to the
  profile.
- `RNF_HOME=/tmp/rnf-alt` with `src/install.sh` installs into `/tmp/rnf-alt`,
  and its `env.sh` names that home.
- With `~/.rn-forge/env.sh` moved aside, a new zsh still has `PATH` and
  completions, through the fallback.
- `mise run verify` for the docs change.

---

# Phase 1 — the kiln scaffold, beside the shell code

**Depends on:** `rn-forge-tooling` 0.4.0 (pykit F28.1), so that installs write
`env.sh` and link the Typer completion.

1. On a branch, render a `python-tool` scaffold into the repository with kiln's
   `kiln new` flow, archetype `python-tool`, docs profile `mkdocs`, Sonar on,
   pinned by `[kiln] ref` as kiln's other consumers are.
2. Leave `src/*.sh`, `tests/*_spec.sh`, `.mise.toml` and `scripts/` in place.
   The shell `rnfmac` stays the shipped product until Phase 4. Move the shell
   payload from `src/` to `shell/` so the Python package can own `src/`, and
   point `scripts/build.sh` and `.mise.toml` at the new path.
3. `ToolProduct` as in *Decisions taken*. `rnfmac version` and the `self`
   group come from tooling, with no code of macsetup's own.
4. Package data: copy `src/profiles/shared/*` and `src/homebrew/**` into the
   package, and load them with `importlib.resources`.
5. Merge the hand-written docs (`docs/architecture/*`, `docs/guides/*`) into the
   scaffold's `docs/` per its `_structure.md`. `docs/reference/` becomes the
   generated CLI reference, and `scripts/shdoc` and `scripts/gen-docs.sh` are
   deleted with the shell code in Phase 4.

**Validation:** `task validate` passes, and `task lint KILN_DOCTOR_FULL=1` is
clean. Under a temporary `RNF_HOME`,
`rnfmac self install --archive <git archive of HEAD> --version 0.0.0` leaves
`$RNF_HOME/bin/rnfmac` and `$RNF_HOME/completions/_rnfmac` linked through
`current`, and `rnfmac self doctor` reports no error. The existing
`$RNF_HOME/macsetup/config/` and `profile.zsh` survive both the install and
`rnfmac self cleanup`. Confirm that last point first: tooling keeps its versions
under `macsetup/versions/`, beside `config/`. If cleanup would touch the
siblings, stop and raise it in pykit before going further.

---

# Phase 2 — port the read-only commands

These change nothing on the machine, so they are the safe place to settle the
Python patterns: a subprocess seam, a fake `$HOME`, and the findings report.

| Shell | Python command | Notes |
| -- | -- | -- |
| `commands/doctor.sh`, `system/doctor.sh`, `lib/report.sh` | `rnfmac doctor`, `rnfmac system doctor` | Findings through `rn-forge-commons`. Keep the exit codes from `docs/guides/commands.md`. `system doctor` stays presence-only (invariant). |
| `config/status.sh`, `config/lib.sh` | `rnfmac config status` | |
| `profile/check.sh`, `profile/lib.sh` | `rnfmac profile check` | |
| `brew/diff.sh`, `lib/dedupe-brewfile.awk` | `rnfmac brew diff` | The dedupe logic becomes a plain function. The awk file and its coverage exclusion go away. |

Write the tests first, porting each `tests/**/*_spec.sh` example to a pytest
case with `tmp_path` as `$HOME` and a fake subprocess runner in place of the
`curl`/`hostname` stubs. **Validation:** every ported spec has a passing pytest
twin, `task test:coverage` meets the scaffold's gate, and running each command
against a real host gives the same report as the shell version.

---

# Phase 3 — port the commands that change the machine

| Shell | Python command | Invariant to keep |
| -- | -- | -- |
| `config/pull.sh`, `push.sh`, `reset.sh` | `rnfmac config pull/push/reset` | `pull` carries local changes across on a stash. |
| `profile/sync.sh` | `rnfmac profile sync` | Patch `.zshrc` before its `source $ZSH/oh-my-zsh.sh` line. Both `.zprofile` and `.zshrc` get the block. |
| `brew/sync.sh` | `rnfmac brew sync` | |
| `brew/relay.sh` | `rnfmac brew relay [--regen]` | Reset `/opt/homebrew` and re-apply the packaged patches every time. |
| `system/sync.sh` | `rnfmac system sync` | Skip a runtime that fails or has no match, and exit 1 at the end if any was skipped. No hard-coded fallback pin. |
| `system/init.sh` | `rnfmac system init [--force]` | oh-my-zsh and its plugins, nvm, SDKMAN. Homebrew and uv move to the bootstrap (Phase 4). |
| `sync.sh` | `rnfmac sync` | Pull config first. If the checkout was absent, clone it and stop without applying. |

`system init` and `system sync` keep the existing convention: no tests, because
they drive real installers over the network, and the scaffold's coverage
exclusion names them. Every other command gets pytest cases first, against the
fake runner.

**Validation:** on a real host, `rnfmac sync` from the Python install leaves
`.zprofile`, `.zshrc`, `profile.zsh` and the Brewfile state byte-identical to
what the shell version produced.

---

# Phase 4 — cutover

1. **Bootstrap.** Replace `shell/install.sh` with a small `bootstrap.sh`,
   published as a release asset, that:
   - installs Homebrew if absent (today's `setup_homebrew`, including the
     `--force` path), then `brew install uv`;
   - installs `rnfmac` from the latest tag with
     `uvx --from git+https://github.com/rn-forge/macsetup@<tag> rnfmac self install`,
     or, given `--archive <file>`, with
     `uvx --from <file> rnfmac self install --archive <file>`;
   - stays sourceable under the current contract: no `set -e`, no `exit`.
2. **Retire the shell product:** `shell/`, `tests/*_spec.sh`, `.shellspec`,
   `.shellcheckrc`, `.mise.toml`, `scripts/`, the shkit fixtures, the kcov job
   and the shell-specific sections of `CLAUDE.md`. `AGENTS.md` becomes kiln's.
   `upgrade`, `cleanup` and `version` are gone, replaced by `self`.
3. **shkit leaves macsetup.** Nothing sources `shkit.sh` any more, and the
   tooling install writes `env.sh` itself. Phase 0's profile guard stays, so a
   host with no `env.sh` still gets `PATH` and completions. shkit stays on hosts
   that use it for other things, and installs on its own.
4. **Migrate each host once:** `rnfmac self install`, then delete the old
   `$RNF_HOME/macsetup/v*` shell versions by hand, then `rnfmac sync`. Leave
   `config/` and `profile.zsh` untouched.
5. Rewrite `README.md` for the new install line and the `task` verbs.

**Validation:** on a fresh macOS user account, the bootstrap line followed by
`rnfmac system init` and `rnfmac sync` produces a working shell, with
`rnfmac <TAB>` and `kiln <TAB>` both completing. The same works with
`--archive` while `githubusercontent.com` is blocked (for example through
`/etc/hosts`).
