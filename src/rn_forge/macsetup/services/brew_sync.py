"""`rnfmac brew sync`: install and clean up Homebrew packages against the host Brewfile."""

from __future__ import annotations

from rn_forge.commons.runtime.console import console

from rn_forge.macsetup.domain.layout import Layout
from rn_forge.macsetup.domain.runner import Runner
from rn_forge.macsetup.services.brew_diff import brewfile_path

__all__ = ["brew_sync"]


def _stream(runner: Runner, args: list[str]) -> None:
    """Stream *args*; the first failure ends the sync with that command's exit code."""
    code = runner.stream(args)
    if code != 0:
        console.error("{} failed with exit code {}", " ".join(args[:3]), code)
        raise SystemExit(code)


def brew_sync(layout: Layout, host: str, runner: Runner) -> None:
    """Install, then clean up, packages against the host's Brewfile.

    Args:
        layout: Where the config checkout is.
        host: The host name, which selects the Brewfile.
        runner: Streams `brew`, so its progress shows live.

    Raises:
        SystemExit: A `brew` command failed; carries its exit code.
    """
    file = f"--file={brewfile_path(layout, host)}"
    _stream(runner, ["brew", "bundle", "install", file, "--verbose", "--force"])
    _stream(runner, ["brew", "bundle", "cleanup", file, "--verbose", "--force"])
    console.success("Brew packages synced successfully")
    _stream(runner, ["brew", "list"])
    console.success("Brew sync complete !")
