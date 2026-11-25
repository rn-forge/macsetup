"""Pure logic for `rnfmac system sync`: merging version lists and resolving Temurin builds."""

from __future__ import annotations

import re

__all__ = ["merge_versions", "resolve_temurin"]


def merge_versions(shared: str | None, host: str | None) -> list[str]:
    """Merge a runtime's shared and host version files into one ordered list.

    `#` comments, surrounding blanks and empty lines are dropped; duplicates are
    removed, keeping the first occurrence, so shared entries come first.

    Args:
        shared: Contents of `shared/<runtime>-versions`, or None when absent.
        host: Contents of `hosts/<host>/<runtime>-versions`, or None when absent.

    Returns:
        One version spec per entry; empty when neither file lists any.
    """
    merged: list[str] = []
    for text in (shared, host):
        for line in (text or "").splitlines():
            spec = line.split("#", 1)[0].strip()
            if spec and spec not in merged:
                merged.append(spec)
    return merged


def resolve_temurin(spec: str, listing: str) -> str | None:
    """Resolve a java version spec to a Temurin identifier from `sdk list java` output.

    A spec ending `-tem` is an exact identifier and is returned as is. Otherwise
    it is matched as a major-version prefix against the identifier column (the
    last `|`-delimited field), which must end `-tem`.

    Args:
        spec: A major version (`21`) or an exact identifier.
        listing: The output of `sdk list java`.

    Returns:
        The first matching identifier, or None.
    """
    if spec.endswith("-tem"):
        return spec
    pattern = re.compile(f"^{re.escape(spec)}([.+]|-tem$)")
    for line in listing.splitlines():
        identifier = line.rsplit("|", 1)[-1].strip()
        if identifier.endswith("-tem") and pattern.match(identifier):
            return identifier
    return None
