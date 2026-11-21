"""The `profile` group: `rnfmac profile check`."""

from __future__ import annotations

from rn_forge.cli import CliApp

from rn_forge.macsetup.commands import output, wiring
from rn_forge.macsetup.commands.output import JsonOption
from rn_forge.macsetup.services.profile_check import profile_check

__all__ = ["check", "profile_app"]


def check(all: bool = False, json: JsonOption = False) -> None:
    """Read-only report: does the installed profile match what `profile sync` would render?

    Exit 0 when current (or the host has no profile), 2 on drift.
    """
    output.use_json(json)
    run = wiring.runner()
    report = profile_check(wiring.layout(), wiring.host(run))
    output.render(report, show_ok=all)
    output.finish(report)


profile_app = CliApp("profile", "The rendered shell profile.")
"""The `profile` namespace; each command is registered on it."""
profile_app.command(name="check")(check)
