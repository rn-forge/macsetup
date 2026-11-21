"""The `system` group: `rnfmac system doctor`."""

from __future__ import annotations

from rn_forge.cli import CliApp

from rn_forge.macsetup.commands import output, wiring
from rn_forge.macsetup.commands.output import JsonOption
from rn_forge.macsetup.services.system_doctor import system_doctor

__all__ = ["doctor", "system_app"]


def doctor(all: bool = False, json: JsonOption = False) -> None:
    """Read-only toolchain health check: presence only, no version is compared.

    Exit 0 when healthy, 2 when configured state has drifted, 1 when the runtime
    layout is broken.
    """
    output.use_json(json)
    report = system_doctor(wiring.layout(), wiring.environment(), wiring.runner())
    output.render(report, show_ok=all)
    output.finish(report)


system_app = CliApp("system", "Machine toolchain and runtime state.")
"""The `system` namespace; each command is registered on it."""
system_app.command(name="doctor")(doctor)
