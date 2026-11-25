"""`rnfmac system doctor`: presence-only toolchain and runtime-layout checks."""

from __future__ import annotations

from collections.abc import Mapping
from pathlib import Path

from rn_forge.macsetup.domain.layout import Layout
from rn_forge.macsetup.domain.report import Report, Status
from rn_forge.macsetup.domain.runner import Runner

__all__ = ["system_doctor"]

TOOLCHAIN = "toolchain"
RUNTIME = "runtime"
OMZ_PLUGINS = ("zsh-completions", "zsh-autosuggestions", "zsh-syntax-highlighting")
RELAY_SUBJECT = "rn-forge: apply Homebrew remote relay"
_INIT = "run 'rnfmac system init'"
_PROFILE_SYNC = "run 'rnfmac profile sync'"


def _live_link(path: Path) -> bool:
    return path.is_symlink() and path.exists()


def _check_homebrew(
    report: Report, layout: Layout, env: Mapping[str, str], runner: Runner
) -> None:
    if not runner.which("brew"):
        report.add(Status.ERROR, TOOLCHAIN, "homebrew", f"homebrew not found — {_INIT}")
        return
    first = runner.run(["brew", "--version"]).stdout.splitlines()
    report.add(Status.OK, TOOLCHAIN, "homebrew", first[0] if first else "")
    custom = Path(env.get("ZSH_CUSTOM") or layout.user_home / ".oh-my-zsh" / "custom")
    for plugin in OMZ_PLUGINS:
        if (custom / "plugins" / plugin).is_dir():
            report.add(
                Status.OK,
                TOOLCHAIN,
                "omz-plugin",
                f"oh-my-zsh plugin '{plugin}' present",
            )
        else:
            report.add(
                Status.DRIFT,
                TOOLCHAIN,
                "omz-plugin",
                f"oh-my-zsh plugin '{plugin}' missing — {_INIT}",
            )


def _check_ohmyzsh(report: Report, layout: Layout) -> None:
    if (layout.user_home / ".oh-my-zsh").is_dir():
        report.add(Status.OK, TOOLCHAIN, "oh-my-zsh", "oh-my-zsh present")
    else:
        report.add(
            Status.DRIFT, TOOLCHAIN, "oh-my-zsh", f"oh-my-zsh not found — {_INIT}"
        )


def _check_runtime_managers(report: Report, layout: Layout, runner: Runner) -> None:
    if runner.which("uv"):
        version = runner.run(["uv", "--version"]).stdout.strip()
        report.add(Status.OK, TOOLCHAIN, "uv", version)
    else:
        report.add(Status.DRIFT, TOOLCHAIN, "uv", f"uv not found — {_INIT}")
    if (layout.user_home / ".nvm").is_dir():
        report.add(Status.OK, TOOLCHAIN, "nvm", "nvm present")
    else:
        report.add(Status.DRIFT, TOOLCHAIN, "nvm", f"nvm not found — {_INIT}")
    if (layout.user_home / ".sdkman" / "bin" / "sdkman-init.sh").is_file():
        report.add(Status.OK, TOOLCHAIN, "sdkman", "sdkman present")
    else:
        report.add(Status.DRIFT, TOOLCHAIN, "sdkman", f"sdkman not found — {_INIT}")


def _check_layout(report: Report, layout: Layout) -> None:
    current = layout.product_home / "current"
    if _live_link(current):
        report.add(
            Status.OK,
            RUNTIME,
            "current-symlink",
            f"macsetup current -> {current.readlink()}",
        )
    else:
        report.add(
            Status.ERROR,
            RUNTIME,
            "current-symlink",
            f"macsetup 'current' symlink missing or broken — {_PROFILE_SYNC}",
        )
    if _live_link(layout.rnf_home / "bin" / "rnfmac"):
        report.add(Status.OK, RUNTIME, "bin-symlink", "bin/rnfmac linked")
    else:
        report.add(
            Status.ERROR,
            RUNTIME,
            "bin-symlink",
            f"bin/rnfmac missing or broken — {_PROFILE_SYNC}",
        )
    if _live_link(layout.rnf_home / "completions" / "_rnfmac"):
        report.add(
            Status.OK, RUNTIME, "completions-symlink", "completions/_rnfmac linked"
        )
    else:
        report.add(
            Status.DRIFT,
            RUNTIME,
            "completions-symlink",
            f"completions/_rnfmac missing or broken — {_PROFILE_SYNC}",
        )


def _check_relay(report: Report, runner: Runner) -> None:
    """Report, never as a problem, whether Homebrew carries the remote relay patch."""
    if not runner.which("brew"):
        return
    prefix_result = runner.run(["brew", "--prefix"])
    prefix = prefix_result.stdout.strip()
    if not prefix_result.ok or not prefix:
        return
    root = Path(prefix)
    if not runner.run(["git", "-C", prefix, "rev-parse", "--show-toplevel"]).ok:
        return
    subject = runner.run(["git", "-C", str(root), "log", "-1", "--pretty=%s"])
    if subject.ok and RELAY_SUBJECT in subject.stdout.splitlines():
        report.add(
            Status.OK,
            RUNTIME,
            "relay",
            "Homebrew is patched with the remote relay (rnfmac brew relay --reset to undo)",
        )
    else:
        report.add(
            Status.OK,
            RUNTIME,
            "relay",
            "Homebrew is on a clean base (no remote relay patch)",
        )


def system_doctor(layout: Layout, env: Mapping[str, str], runner: Runner) -> Report:
    """Check the toolchain and the runtime layout. Presence only: no version is compared."""
    report = Report("system")
    _check_homebrew(report, layout, env, runner)
    _check_ohmyzsh(report, layout)
    _check_runtime_managers(report, layout, runner)
    _check_layout(report, layout)
    _check_relay(report, runner)
    return report
