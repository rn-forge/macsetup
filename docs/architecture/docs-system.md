# Documentation system

macsetup publishes one MkDocs site, built and validated by kiln's `python-tool`
tasks. Handwritten guidance and the generated Python API reference share one
navigation tree, so readers get one place to search and browse and each page
still has one source of truth.

## Sources of truth

| Content | Source | Versioned |
| -- | -- | -- |
| Landing page, architecture, guides, runbooks, specs and decisions | Handwritten Markdown under `docs/`, laid out as `docs/_structure.md` says | Yes |
| Python API reference | Docstrings under `src/`, rendered by `mkdocstrings` into `docs/reference/python-api.md` | Yes (the page is a stub that renders the docstrings) |
| Navigation | `docs/_areas.yml` and the tree, derived into `mkdocs.yml` by `task docs:generate` | Yes |
| Project front door | `README.md` | Yes; brief summaries link to the site |

The README is intentionally limited to what macsetup is, installation, a quick
start, and short links into the site. Longer explanations live exactly once in
the site so they do not drift between two versions.

## Validation and publishing

`task docs:build` builds into `.docs-site/` with MkDocs strict mode, so a broken
link, anchor or navigation target fails the build. `task validate` runs it after
`kiln doctor`, whose `docs-structure` and `docs-generate` checks hold the tree
to the rules in `docs/_structure.md`: area layout, ADR numbering, link and
anchor resolution, and a current derived nav. `mkdocs.yml` is generated from
`.rn-forge/kiln/config.toml`; change the configuration and run
`task kiln:apply`, never the file.

The `Docs` workflow (`_docs.yml`, called from `ci.yml` after the checks pass on
`main`) runs `task docs:build` and publishes `.docs-site/` to GitHub Pages.
Pages must be enabled once in repository settings with **Source: GitHub
Actions**.

## Maintenance rule

Treat `docs/_areas.yml` and the tree as the canonical site structure. Add each
new handwritten page under the area it belongs to, run `task docs:generate`, and
link related pages instead of duplicating their content. When the documentation
tooling, generation boundary, validation, or publishing workflow changes, update
this page and add a changelog entry.

## Changelog

- 2026-08-31: Established one MkDocs site for handwritten guides and generated
  shell reference, with strict builds, link/orphan linting, and GitHub Pages
  publishing.
- 2026-08-31: Replaced the `scripts/check-docs.py` doc-linter with native MkDocs
  `validation:` config (`nav.omitted_files`, `links.anchors` raised to `warn`)
  plus `not_in_nav` for the generated reference tree — MkDocs 1.5+ already
  validates broken links and missing nav targets by default under
  `strict: true`, so the custom script duplicated most of what the tool does
  natively.
- 2026-11-21: Moved the site onto the kiln `python-tool` scaffold (Phase 1 of
  the port plan). `mkdocs.yml` is generated and its nav derived from
  `docs/_areas.yml`; the site is built by `task docs:build` and published by
  the generated `_docs.yml` workflow, replacing `mise run docs-site` and the
  hand-written `docs.yml`. The shell reference moved from `docs/reference/` to
  the gitignored `docs/reference/shell/`; the Python API reference now owns
  `docs/reference/`.
- 2026-11-23: Retired the shell reference with the shell product: `shdoc`,
  `scripts/gen-docs.sh`, `mise run docs` and the gitignored
  `docs/reference/shell/` are gone, and the Python API reference is the only
  generated reference.
