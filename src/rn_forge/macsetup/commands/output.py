"""How the read-only commands print a report and choose an exit code."""

from __future__ import annotations

from rich.markup import escape
from rn_forge.cli import JsonOption
from rn_forge.commons.runtime.console import OutputMode, console

from rn_forge.macsetup.domain.report import CATEGORY_ORDER, Report, Status

__all__ = ["JsonOption", "finish", "render", "say", "use_json"]

_ORDER = (Status.ERROR, Status.DRIFT, Status.WARNING, Status.OK)


def use_json(flag: bool) -> None:
    """Switch the console to JSON mode when *flag* is set."""
    if flag:
        console.set_mode(OutputMode.JSON)


def say(text: str) -> None:
    """Print *text* to stdout as written: no markup, no wrapping. Silent in quiet and JSON modes."""
    if console.mode in (OutputMode.QUIET, OutputMode.JSON):
        return
    console.rich.print(text, markup=False, highlight=False, soft_wrap=True)


def render(report: Report, *, show_ok: bool) -> None:
    """Print *report*: JSON in JSON mode, else category-grouped lines and a summary.

    Healthy records are hidden unless *show_ok*.
    """
    counts = {status: report.count(status) for status in _ORDER}
    if console.mode is OutputMode.JSON:
        console.json(
            {
                "findings": [
                    {
                        "code": finding.code,
                        "severity": finding.severity.value,
                        "message": finding.message,
                        "details": finding.details,
                    }
                    for finding in report.findings()
                ],
                "summary": {status.value: n for status, n in counts.items()},
            }
        )
        return
    for category in CATEGORY_ORDER:
        records = [r for r in report.records if r.category == category]
        if not records:
            continue
        say(category)
        for status in _ORDER:
            if status is Status.OK and not show_ok:
                continue
            for record in records:
                if record.status is not status:
                    continue
                text = escape(record.message)
                if status is Status.ERROR:
                    console.error("{}", text)
                elif status is Status.OK:
                    console.success("{}", text)
                else:
                    console.warning("{}", text)
    say(
        f"{counts[Status.OK]} ok, {counts[Status.WARNING]} warning, "
        f"{counts[Status.DRIFT]} drift, {counts[Status.ERROR]} error"
    )


def finish(report: Report) -> None:
    """Exit with the report's code when it is not 0."""
    if report.exit_code:
        raise SystemExit(report.exit_code)
