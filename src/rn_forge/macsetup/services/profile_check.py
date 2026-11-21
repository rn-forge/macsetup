"""`rnfmac profile check`: does the installed profile match what `profile sync` would render?"""

from __future__ import annotations

from pathlib import Path

from rn_forge.commons.exceptions import AppException

from rn_forge.macsetup.domain.layout import Layout
from rn_forge.macsetup.domain.report import Report, Status

__all__ = ["profile_check", "render_profile"]

PROFILE = "profile"
_SYNC = "run 'rnfmac profile sync'"


def render_profile(layout: Layout, host: str) -> bytes:
    """Render the shared profile, aliases and host profile into one `profile.zsh`.

    The host profile comes last so that it wins.

    Raises:
        AppException: A source file is missing.
    """
    config = layout.config_home
    return b"".join(
        (
            "#################### macsetup profile — rendered by profile/sync.sh, DO NOT EDIT\n".encode(),
            _read(config / "shared" / "profile.zsh"),
            b"\n#################### aliases\n",
            _read(config / "shared" / "aliases.zsh"),
            f"\n#################### host overrides: {host}\n".encode(),
            _read(config / "hosts" / host / "profile.zsh"),
        )
    )


def _read(path: Path) -> bytes:
    try:
        return path.read_bytes()
    except OSError as error:
        raise AppException("cannot render the profile: {} ({})", path, error) from error


def _patched(layout: Layout, rc: Path) -> bool:
    try:
        text = rc.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return False
    return layout.marker in text and layout.source_line in text


def profile_check(layout: Layout, host: str) -> Report:
    """Check the host profile exists, the rendered profile is fresh and both rc files are patched."""
    report = Report(PROFILE)
    host_profile = layout.config_home / "hosts" / host / "profile.zsh"
    if not host_profile.is_file():
        report.add(
            Status.WARNING,
            PROFILE,
            "host-profile",
            f"no profile for host '{host}' — create hosts/{host}/ in macsetup-config",
        )
        return report

    rendered = layout.rendered_profile
    if not rendered.is_file():
        report.add(
            Status.DRIFT,
            PROFILE,
            "rendered-profile",
            f"no rendered profile at {rendered} — {_SYNC}",
        )
    elif rendered.read_bytes() != render_profile(layout, host):
        report.add(
            Status.DRIFT,
            PROFILE,
            "rendered-profile",
            f"rendered profile.zsh is stale — {_SYNC}",
        )
    else:
        report.add(
            Status.OK, PROFILE, "rendered-profile", "rendered profile.zsh is up to date"
        )

    for name, check in ((".zprofile", "zprofile"), (".zshrc", "zshrc")):
        if _patched(layout, layout.user_home / name):
            report.add(Status.OK, PROFILE, check, f"{name} is patched")
        else:
            report.add(
                Status.DRIFT,
                PROFILE,
                check,
                f"{name} is missing the macsetup marker/profile lines — {_SYNC}",
            )
    return report
