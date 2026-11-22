"""The `brew` group: `rnfmac brew diff`."""

from __future__ import annotations

from rich.markup import escape
from rn_forge.cli import CliApp
from rn_forge.commons.runtime.console import OutputMode, console

from rn_forge.macsetup.commands import output, wiring
from rn_forge.macsetup.commands.output import JsonOption
from rn_forge.macsetup.domain.runner import Result
from rn_forge.macsetup.services.brew_diff import brew_diff, write_brewfile
from rn_forge.macsetup.services.brew_sync import brew_sync

__all__ = ["brew_app", "diff", "sync"]


def show_stderr(result: Result) -> None:
    """Print brew's own complaint, which it writes to stderr."""
    if result.stderr.strip():
        console.warning("{}", escape(result.stderr.rstrip("\n")))


def show_all(result: Result) -> None:
    """Print brew's own output for the check, as the shell version let it through."""
    if result.stdout.strip():
        output.say(result.stdout.rstrip("\n"))
    show_stderr(result)


def diff(all: bool = False, write: bool = False, json: JsonOption = False) -> None:
    """Report drift between installed Homebrew packages and the host Brewfile.

    `--write` instead rewrites the host Brewfile in the config checkout from the
    installed packages. Exit 0 when there is no drift, 2 on drift, 1 on error.
    """
    output.use_json(json)
    run = wiring.runner()
    layout = wiring.layout()
    host = wiring.host(run)
    if write:
        target = write_brewfile(layout, host, run)
        console.success("Brewfile updated at {}", escape(str(target)))
        return
    human = console.mode is not OutputMode.JSON
    report = brew_diff(layout, host, run, show_output=show_all if human else None)
    output.render(report, show_ok=all)
    output.finish(report)


brew_app = CliApp("brew", "Homebrew packages and the Brewfile.")
"""The `brew` namespace; each command is registered on it."""
brew_app.command(name="diff")(diff)


def sync() -> None:
    """Install, then clean up, Homebrew packages against the host Brewfile."""
    run = wiring.runner()
    layout = wiring.layout()
    host = wiring.host(run)
    brew_sync(layout, host, run)


brew_app.command(name="sync")(sync)
