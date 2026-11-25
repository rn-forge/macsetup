"""The `config` group: `rnfmac config status|pull|push|reset`."""

from __future__ import annotations

from rich.markup import escape
from rn_forge.cli import CliApp
from rn_forge.commons.exceptions import AppException
from rn_forge.commons.runtime.console import console

from rn_forge.macsetup.commands import output, wiring
from rn_forge.macsetup.services.config_status import config_status
from rn_forge.macsetup.services.config_sync import (
    config_pull,
    config_push,
    config_repo_url,
    config_reset,
)

__all__ = ["config_app", "pull", "push", "reset", "status"]


def notify(kind: str, text: str) -> None:
    """Print one progress line from a config service."""
    if kind == "success":
        console.success("{}", escape(text))
    elif kind in ("info", "notice"):
        console.info("{}", escape(text))
    else:
        output.say(text)


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


def pull() -> None:
    """Clone the config checkout when absent, else fast-forward it onto origin/main.

    Uncommitted local changes are carried across the update on a stash.
    """
    config_pull(
        wiring.layout(),
        wiring.runner(),
        config_repo_url(wiring.environment()),
        notify,
    )


def push(message: str | None = None) -> None:
    """Commit local config changes and publish them to origin/main.

    The commit message defaults to the host name.
    """
    run = wiring.runner()
    if message is None:
        message = wiring.host(run)
    elif not message.strip():
        raise AppException("the commit message must not be empty")
    config_push(wiring.layout(), run, message, notify)


def reset(force: bool = False) -> None:
    """Hard-reset the config checkout to origin/main; refuses to discard changes without --force."""
    config_reset(wiring.layout(), wiring.runner(), force, notify)


config_app = CliApp("config", "The macsetup-config checkout.")
"""The `config` namespace; each command is registered on it."""
config_app.command(name="status")(status)
config_app.command(name="pull")(pull)
config_app.command(name="push")(push)
config_app.command(name="reset")(reset)
