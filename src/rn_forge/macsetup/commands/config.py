"""The `config` group: `rnfmac config status`."""

from __future__ import annotations

from rich.markup import escape
from rn_forge.cli import CliApp
from rn_forge.commons.runtime.console import console

from rn_forge.macsetup.commands import output, wiring
from rn_forge.macsetup.services.config_status import config_status

__all__ = ["config_app", "status"]


def status() -> None:
    """Show the config checkout's branch, revision, remote state and local diff.

    Fetches origin read-only; an unreachable remote is reported, not fatal.
    """
    for kind, text in config_status(wiring.layout(), wiring.runner()):
        if kind == "success":
            console.success("{}", escape(text))
        elif kind == "notice":
            console.info("{}", escape(text))
        else:
            output.say(text)


config_app = CliApp("config", "The macsetup-config checkout.")
"""The `config` namespace; each command is registered on it."""
config_app.command(name="status")(status)
