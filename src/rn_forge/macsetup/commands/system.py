"""The `system` group: `rnfmac system doctor`, `sync` and `init`."""

from __future__ import annotations

from rn_forge.cli import CliApp
from rn_forge.commons.runtime.console import console

from rn_forge.macsetup.commands import output, wiring
from rn_forge.macsetup.commands.output import JsonOption
from rn_forge.macsetup.services.system_doctor import system_doctor
from rn_forge.macsetup.services.system_init import system_init
from rn_forge.macsetup.services.system_sync import system_sync

__all__ = ["doctor", "init", "sync", "system_app"]


def doctor(all: bool = False, json: JsonOption = False) -> None:
    """Read-only toolchain health check: presence only, no version is compared.

    Exit 0 when healthy, 2 when configured state has drifted, 1 when the runtime
    layout is broken.
    """
    output.use_json(json)
    report = system_doctor(wiring.layout(), wiring.environment(), wiring.runner())
    output.render(report, show_ok=all)
    output.finish(report)


def sync() -> None:
    """Install the python, node and java versions pinned in macsetup-config.

    A version that cannot be installed is logged and skipped; exit 1 when any
    was skipped or a runtime has no version list.
    """
    run = wiring.runner()
    if not system_sync(wiring.layout(), wiring.host(run), run):
        raise SystemExit(1)
    console.success("System sync complete !")


def init(force: bool = False) -> None:
    """Bootstrap a new macOS system: oh-my-zsh and plugins, nvm and SDKMAN.

    Components already present are skipped; --force removes and reinstalls them.
    Homebrew and uv are left to the bootstrap.
    """
    system_init(wiring.layout(), wiring.environment(), wiring.runner(), force=force)
    console.success("System setup complete !")
    console.info("behind a corporate network/Zscaler? run 'rnfmac brew relay'")


system_app = CliApp("system", "Machine toolchain and runtime state.")
"""The `system` namespace; each command is registered on it."""
system_app.command(name="doctor")(doctor)
system_app.command(name="sync")(sync)
system_app.command(name="init")(init)
