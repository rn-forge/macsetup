"""`rnfmac doctor`: one read-only sweep over the system, profile and brew checks."""

from __future__ import annotations

from rn_forge.macsetup.commands import output, wiring
from rn_forge.macsetup.commands.brew import show_stderr
from rn_forge.macsetup.commands.output import JsonOption
from rn_forge.macsetup.domain.report import Report
from rn_forge.macsetup.services.brew_diff import brew_diff
from rn_forge.macsetup.services.profile_check import profile_check
from rn_forge.macsetup.services.system_doctor import system_doctor

__all__ = ["collect", "doctor"]


def collect() -> Report:
    """Run system doctor, profile check and brew diff, and merge their records."""
    run = wiring.runner()
    layout = wiring.layout()
    host = wiring.host(run)
    report = Report("doctor")
    report.extend(system_doctor(layout, wiring.environment(), run))
    report.extend(profile_check(layout, host))
    report.extend(brew_diff(layout, host, run, show_output=show_stderr))
    return report


def doctor(all: bool = False, json: JsonOption = False) -> None:
    """Read-only health sweep across the system, profile and brew groups.

    Healthy records are hidden unless `--all`. Exit 0 when healthy or only
    warned, 2 when installed state has drifted, 1 when macsetup is broken.
    """
    output.use_json(json)
    report = collect()
    output.render(report, show_ok=all)
    output.finish(report)
