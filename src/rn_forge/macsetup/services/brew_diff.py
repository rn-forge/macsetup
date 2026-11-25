"""`rnfmac brew diff`: drift between installed Homebrew packages and the host Brewfile."""

from __future__ import annotations

from collections.abc import Callable
from pathlib import Path

from rn_forge.commons.exceptions import AppException

from rn_forge.macsetup.domain.brewfile import dedupe_brewfile
from rn_forge.macsetup.domain.layout import Layout
from rn_forge.macsetup.domain.report import Report, Status
from rn_forge.macsetup.domain.runner import Result, Runner

__all__ = ["brew_diff", "brewfile_path", "write_brewfile"]

PACKAGES = "packages"
_CLEANUP_TAIL = "Would `brew cleanup`:"


def brewfile_path(layout: Layout, host: str) -> Path:
    """The host's Brewfile in the config checkout.

    Raises:
        AppException: The host name would place the Brewfile outside `hosts/`.
    """
    hosts = (layout.config_home / "hosts").resolve()
    path = (hosts / host / "Brewfile").resolve()
    if not path.is_relative_to(hosts) or path.parent == hosts:
        raise AppException("invalid host name {!r}", host)
    return path


def _extras(cleanup: Result) -> str:
    """The `brew bundle cleanup` listing, up to the line that starts the `brew cleanup` preview."""
    kept: list[str] = []
    for line in cleanup.stdout.splitlines():
        if line == _CLEANUP_TAIL:
            break
        kept.append(line)
    return "\n".join(kept).strip("\n")


def brew_diff(
    layout: Layout,
    host: str,
    runner: Runner,
    *,
    show_output: Callable[[Result], None] | None = None,
) -> Report:
    """Report drift between installed packages and the host Brewfile.

    Args:
        layout: Where the config checkout is.
        host: The host name, which selects the Brewfile.
        runner: Runs `brew`.
        show_output: Called with the result of `brew bundle check`, so a human
            report can show brew's own detail. Left out for JSON and for the
            combined doctor report.
    """
    report = Report("brew")
    brewfile = str(brewfile_path(layout, host))
    check = runner.run(["brew", "bundle", "check", f"--file={brewfile}", "--verbose"])
    if show_output is not None:
        show_output(check)
    missing = not check.ok

    extras = _extras(runner.run(["brew", "bundle", "cleanup", f"--file={brewfile}"]))
    if extras:
        report.add(
            Status.DRIFT,
            PACKAGES,
            "brewfile-extra",
            f"installed but not in Brewfile:\n{extras}",
        )
    if not missing and not extras:
        report.add(
            Status.OK,
            PACKAGES,
            "brewfile",
            "no drift — installed packages match the Brewfile",
        )
    elif missing:
        report.add(
            Status.DRIFT,
            PACKAGES,
            "brewfile-missing",
            "packages from the Brewfile are missing — run 'rnfmac brew sync'",
        )
    return report


def write_brewfile(layout: Layout, host: str, runner: Runner) -> Path:
    """Dump the installed packages into the host's Brewfile in the config checkout.

    Dependency-only formulae are dropped, keeping those installed on request.

    Raises:
        AppException: The checkout is missing, or a `brew` command failed.
    """
    config = layout.config_home
    if not runner.run(
        ["git", "-C", str(config), "rev-parse", "--is-inside-work-tree"]
    ).ok:
        raise AppException("macsetup config checkout is missing at {}", config)
    target = brewfile_path(layout, host)
    target.parent.mkdir(parents=True, exist_ok=True)
    dump = runner.run(
        [
            "brew",
            "bundle",
            "dump",
            f"--file={target}",
            "--force",
            "--no-vscode",
            "--no-uv",
            "--no-npm",
        ]
    )
    if not dump.ok:
        raise AppException("brew bundle dump failed: {}", dump.stderr.strip())
    listed = runner.run(["brew", "list", "--formula", "--installed-on-request"])
    if not listed.ok:
        raise AppException("brew list failed: {}", listed.stderr.strip())
    requested = set(listed.stdout.splitlines())
    target.write_text(
        dedupe_brewfile(target.read_text(encoding="utf-8"), requested),
        encoding="utf-8",
    )
    return target
