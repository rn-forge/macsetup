# Documentation system

macsetup publishes one MkDocs site containing both handwritten guidance and generated shell API reference. A single navigation tree gives readers one place to search and browse, while each page still has one clear source of truth.

## Sources of truth

| Content | Source | Versioned |
| --- | --- | --- |
| Landing page, architecture, guides, and specifications | Handwritten Markdown under `docs/` | Yes |
| Shell API reference | `shdoc` annotations under `src/` | No; generated into `docs/reference/` |
| Project front door | `README.md` | Yes; brief summaries link to the site |

Run `mise run docs` to replace the generated reference. Never hand-edit `docs/reference/` or copy its function-level detail into handwritten pages.

The README is intentionally limited to what macsetup is, installation, a quick start, and short links into the site. Longer explanations live exactly once in the site so they do not drift between two versions.

## Validation and publishing

`mise run docs-site` builds into `site/` with MkDocs strict mode. `mkdocs.yml`'s `validation:`
block raises `nav.omitted_files` and `links.anchors` from MkDocs' default `info` level to `warn`,
so strict mode turns broken links, bad anchors, missing navigation targets, and orphan pages into
build failures — no separate doc-linter script. `not_in_nav: reference/**` excludes the generated
reference tree from the orphan check, since only `reference/index.md` sits in `mkdocs.yml`'s nav
and the rest are reached by links from it rather than being individually listed.

`mise run verify` generates the reference and builds the site. The dedicated GitHub Pages workflow
repeats generation and the strict build before publishing `site/`. GitHub Pages must be enabled
once in repository settings with **Source: GitHub Actions**.

## Maintenance rule

Treat `mkdocs.yml` navigation as the canonical site structure. Add each new handwritten page there and link related pages instead of duplicating their content. When the documentation tooling, generation boundary, validation, or publishing workflow changes, update this page and add a changelog entry.

## Changelog

- 2026-08-31: Established one MkDocs site for handwritten guides and generated shell reference, with strict builds, link/orphan linting, and GitHub Pages publishing.
- 2026-08-31: Replaced the `scripts/check-docs.py` doc-linter with native MkDocs `validation:` config (`nav.omitted_files`, `links.anchors` raised to `warn`) plus `not_in_nav` for the generated reference tree — MkDocs 1.5+ already validates broken links and missing nav targets by default under `strict: true`, so the custom script duplicated most of what the tool does natively.
