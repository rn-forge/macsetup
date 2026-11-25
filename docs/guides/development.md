# Development

Everything goes through `task`. Nobody — human, agent or CI — invokes `uv`,
`pytest`, `ruff`, `pyright`, `mkdocs` or `kiln` directly; `kiln doctor`'s
`ci-entrypoint` check fails the build if a workflow step does.

```bash
task setup       # sync the venv with the dev and docs groups
task validate    # the whole gate: lint, typecheck, test, docs build
task format      # ruff format + fix, in place
task docs:serve  # live docs on http://127.0.0.1:8080
```

## The ten root verbs

`setup`, `validate`, `lint`, `format`, `typecheck`, `test`, `test:coverage`,
`build`, `clean`, `version` — plus the public `docs:build`, `docs:serve`,
`docs:generate`. Every other task is `internal: true` and exists to be composed
by a wrapper. That list is fixed by kiln ADR-0007, and `kiln doctor`'s
`task-layout` check fails if a gate stops being reachable from `validate`.

## After changing a generated file

Don't. Change `.rn-forge/kiln/config.toml` and run `kiln apply`. If you edited
one anyway, `task lint` will tell you which file drifted and from what.

## After adding a docs page

Run `task docs:generate` — `task lint` fails on a stale nav.

## The package

macsetup is a kiln `python-tool`: the package in `src/rn_forge/macsetup/` holds
the `ToolProduct`, the CLI declaration and the zsh theme, keybindings and
Homebrew Remote Relay patches, packaged under `assets/` and read through
`rn_forge.macsetup.assets`.

Commands follow one pattern: a Typer function in `commands/` over a service in
`services/` that takes a `Layout` (paths resolved from `$HOME`/`$RNF_HOME`) and
a `Runner`, the one seam for `git`, `brew`, `hostname` and `uv`
(`domain/runner.py`; the real one is `adapters/process.py`). Tests replace the
runner with `FakeRunner` from `tests/support.py`, which scripts everything but
`git`, and an autouse fixture in `tests/conftest.py` points `HOME` and
`RNF_HOME` into `tmp_path`. Run them with
`RNF_HOME=/nonexistent-guard task validate`.

`system init` and `system sync` have no tests by convention: they drive real
Homebrew, oh-my-zsh, uv, nvm and SDKMAN installers without a mockable seam, and
Sonar excludes them from coverage.
