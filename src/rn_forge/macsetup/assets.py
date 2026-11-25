"""The files `rnfmac` installs onto a machine, shipped as package data.

They are the zsh theme and macOS keybindings that `profile sync` installs, and the
Homebrew Remote Relay patches and download strategy that `brew relay` applies.
They live under `assets/` in this package and are read through
`importlib.resources`, so they are found the same way from a checkout and from
an installed wheel.
"""

from __future__ import annotations

from importlib.resources import files
from importlib.resources.abc import Traversable

__all__ = ["asset", "asset_names", "read_asset"]

_ROOT = files("rn_forge.macsetup").joinpath("assets")


def asset(*parts: str) -> Traversable:
    """Return the shipped asset at *parts*, relative to ``assets/``."""
    node = _ROOT
    for part in parts:
        node = node.joinpath(part)
    return node


def asset_names(*parts: str) -> list[str]:
    """Return the sorted names of the entries in the asset directory *parts*."""
    return sorted(entry.name for entry in asset(*parts).iterdir())


def read_asset(*parts: str) -> bytes:
    """Return the bytes of the shipped asset at *parts*.

    Raises:
        FileNotFoundError: There is no such asset.
    """
    return asset(*parts).read_bytes()
