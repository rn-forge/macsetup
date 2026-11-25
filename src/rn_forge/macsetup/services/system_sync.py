"""`rnfmac system sync`: install the pinned python, node and java runtimes."""

from __future__ import annotations

from pathlib import Path

from rn_forge.commons.runtime.console import console

from rn_forge.macsetup.domain.layout import Layout
from rn_forge.macsetup.domain.runner import Result, Runner
from rn_forge.macsetup.domain.runtimes import merge_versions, resolve_temurin

__all__ = ["system_sync"]

_SCRIPT = 'export PAGER=cat; source "$1" && shift && "$@"'


def _versions(layout: Layout, host: str, runtime: str) -> list[str]:
    """The merged version list for *runtime*; logs an error and returns [] when empty."""

    def read(path: Path) -> str | None:
        return path.read_text() if path.is_file() else None

    name = f"{runtime}-versions"
    specs = merge_versions(
        read(layout.config_home / "shared" / name),
        read(layout.config_home / "hosts" / host / name),
    )
    if not specs:
        console.error(
            "no {} versions configured — add shared/{} or hosts/{}/{} to macsetup-config",
            runtime,
            name,
            host,
            name,
        )
    return specs


def shell_args(init: Path, command: list[str]) -> list[str]:
    """The argv that runs *command* in a child zsh after sourcing *init*.

    nvm and SDKMAN are shell functions, so each call needs its own shell; the
    command is passed as argv, never interpolated into the script.
    """
    return ["zsh", "-c", _SCRIPT, "_", str(init), *command]


def _run(runner: Runner, init: Path, command: list[str]) -> Result:
    return runner.run(shell_args(init, command))


def _stream(runner: Runner, init: Path, command: list[str]) -> int:
    return runner.stream(shell_args(init, command))


def _sync_python(layout: Layout, host: str, runner: Runner) -> bool:
    console.info("Syncing python runtimes ...")
    specs = _versions(layout, host, "python")
    if not specs:
        return False
    installed: list[str] = []
    failed = False
    for spec in specs:
        console.info("Installing python {} ...", spec)
        if runner.stream(["uv", "python", "install", spec]) == 0:
            installed.append(spec)
        else:
            console.error("python {} not available — skipping", spec)
            failed = True
    if not installed:
        console.error("no python versions were installed")
        return False
    runner.stream(["uv", "python", "install", installed[0], "--default"])
    version = runner.run(
        [str(layout.user_home / ".local" / "bin" / "python"), "--version"]
    )
    console.success(
        "python runtimes synced (default: {}, {})",
        installed[0],
        (version.stdout or version.stderr).strip(),
    )
    return not failed


def _sync_node(layout: Layout, host: str, runner: Runner) -> bool:
    console.info("Syncing node runtimes ...")
    init = layout.user_home / ".nvm" / "nvm.sh"
    specs = _versions(layout, host, "node")
    if not specs:
        return False
    installed: list[str] = []
    failed = False
    for spec in specs:
        console.info("Installing node {} ...", spec)
        install = (
            ["nvm", "install", "--lts"] if spec == "lts" else ["nvm", "install", spec]
        )
        if _stream(runner, init, install) != 0:
            console.error("node {} not available — skipping", spec)
            failed = True
            continue
        found = _run(
            runner, init, ["nvm", "version", "lts/*" if spec == "lts" else spec]
        )
        installed.append(found.stdout.strip() or spec)
    if not installed:
        console.error("no node versions were installed")
        return False
    _stream(runner, init, ["nvm", "alias", "default", installed[0]])
    out = _run(runner, init, ["nvm", "exec", "default", "node", "--version"])
    lines = out.stdout.strip().splitlines()
    console.success(
        "node runtimes synced (default: {}, {})",
        installed[0],
        lines[-1] if lines else "",
    )
    return not failed


def _sync_java(layout: Layout, host: str, runner: Runner) -> bool:
    console.info("Syncing java runtimes ...")
    init = layout.user_home / ".sdkman" / "bin" / "sdkman-init.sh"
    specs = _versions(layout, host, "java")
    if not specs:
        return False
    console.info("Searching for java versions ...")
    listing = _run(runner, init, ["sdk", "list", "java"]).stdout
    installed: list[str] = []
    failed = False
    for spec in specs:
        identifier = resolve_temurin(spec, listing)
        if identifier is None:
            console.error("no Temurin build found for java '{}' — skipping", spec)
            failed = True
            continue
        console.info("Installing java {} ...", identifier)
        if _stream(runner, init, ["sdk", "install", "java", identifier]) == 0:
            installed.append(identifier)
        else:
            console.error("failed to install java {} — skipping", identifier)
            failed = True
    if not installed:
        console.error("no java versions were installed")
        return False
    _stream(runner, init, ["sdk", "default", "java", installed[0]])
    console.success("java runtimes synced (default: {})", installed[0])
    return not failed


def system_sync(layout: Layout, host: str, runner: Runner) -> bool:
    """Install every configured python, node and java version.

    Each runtime is attempted even when an earlier one failed. A version that
    cannot be resolved or installed is logged and skipped.

    Args:
        layout: Where the config checkout is.
        host: The host name, which selects the host version files.
        runner: Runs `uv`, `nvm` and `sdk`.

    Returns:
        True when nothing was skipped and every runtime had a version list.
    """
    results = [
        _sync_python(layout, host, runner),
        _sync_node(layout, host, runner),
        _sync_java(layout, host, runner),
    ]
    return all(results)
