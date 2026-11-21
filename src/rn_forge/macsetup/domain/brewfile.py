"""Regrouping a `brew bundle dump` Brewfile."""

from __future__ import annotations

from collections.abc import Collection

__all__ = ["dedupe_brewfile"]

_HEADERS = {"tap": "## taps", "brew": "## formulae", "cask": "## casks"}


def dedupe_brewfile(text: str, requested: Collection[str]) -> str:
    """Regroup *text* under `## taps`/`## formulae`/`## casks` and drop dependency-only formulae.

    A `brew "name"` line is dropped, with the comment above it, when *name* is
    not in *requested*. A comment is kept only when it sits directly above the
    line it describes. A new group starts, after a blank line, whenever the first
    word of a line changes.
    """
    out: list[str] = []
    pending = ""
    last_type = ""
    for line in text.splitlines():
        if line.startswith("#"):
            pending = line
            continue
        if line.startswith('brew "'):
            name = line[len('brew "') :].split('"', 1)[0]
            if name not in requested:
                pending = ""
                continue
        words = line.split()
        kind = words[0] if words else ""
        if kind != last_type:
            if last_type:
                out.append("")
            if kind in _HEADERS:
                out.append(_HEADERS[kind])
            last_type = kind
        if pending:
            out.append(pending)
        pending = ""
        out.append(line)
    return "".join(f"{line}\n" for line in out)
