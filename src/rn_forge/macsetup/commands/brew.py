"""The `brew` group: `rnfmac brew diff`."""

from __future__ import annotations

from contextlib import ExitStack
from importlib.resources import as_file
from pathlib import Path

from rich.markup import escape
from rn_forge.cli import CliApp, ExitCode
from rn_forge.commons.runtime.console import OutputMode, console

from rn_forge.macsetup import assets
from rn_forge.macsetup.commands import output, wiring
from rn_forge.macsetup.commands.output import JsonOption
from rn_forge.macsetup.domain.runner import Result
from rn_forge.macsetup.services import brew_relay
from rn_forge.macsetup.services.brew_diff import brew_diff, write_brewfile
from rn_forge.macsetup.services.brew_sync import brew_sync

__all__ = ["brew_app", "diff", "relay", "sync"]


def show_stderr(result: Result) -> None:
    """Print brew's own complaint, which it writes to stderr."""
    if result.stderr.strip():
        console.warning("{}", escape(result.stderr.rstrip("\n")))


def show_all(result: Result) -> None:
    """Print brew's own output for the check, as the shell version let it through."""
    if result.stdout.strip():
        output.say(result.stdout.rstrip("\n"))
    show_stderr(result)


def diff(all: bool = False, write: bool = False, json: JsonOption = False) -> None:
    """Report drift between installed Homebrew packages and the host Brewfile.

    `--write` instead rewrites the host Brewfile in the config checkout from the
    installed packages. Exit 0 when there is no drift, 2 on drift, 1 on error.
    """
    output.use_json(json)
    run = wiring.runner()
    layout = wiring.layout()
    host = wiring.host(run)
    if write:
        target = write_brewfile(layout, host, run)
        console.success("Brewfile updated at {}", escape(str(target)))
        return
    human = console.mode is not OutputMode.JSON
    report = brew_diff(layout, host, run, show_output=show_all if human else None)
    output.render(report, show_ok=all)
    output.finish(report)


brew_app = CliApp("brew", "Homebrew packages and the Brewfile.")
"""The `brew` namespace; each command is registered on it."""
brew_app.command(name="diff")(diff)


def sync() -> None:
    """Install, then clean up, Homebrew packages against the host Brewfile."""
    run = wiring.runner()
    layout = wiring.layout()
    host = wiring.host(run)
    brew_sync(layout, host, run)


brew_app.command(name="sync")(sync)


def relay(force: bool = False, reset: bool = False, regen: bool = False) -> None:
    """Apply the Homebrew Remote Relay patches to the local Homebrew install.

    Every apply resets Homebrew to its clean base and re-applies the packaged
    patches. `--force` also runs `brew update`; `--reset` only removes the relay;
    `--regen` rewrites the patch files from hand edits in a clean-base Homebrew.
    """
    if force and reset:
        console.error("--force and --reset are mutually exclusive")
        raise SystemExit(ExitCode.USAGE)
    run = wiring.runner()
    prefix = wiring.layout().homebrew_prefix
    brew_relay.ensure_homebrew_repo(prefix, run)
    with ExitStack() as stack:
        strategy = Path(
            str(
                stack.enter_context(
                    as_file(
                        assets.asset(
                            "homebrew",
                            "download_strategy",
                            "remote_relay_curl_download_strategy.rb",
                        )
                    )
                )
            )
        )
        patches = Path(
            str(stack.enter_context(as_file(assets.asset("homebrew", "patches"))))
        )
        if regen:
            root = brew_relay.checkout_root(patches, run)
            mirror = root / "shell" / "homebrew" / "patches"
            brew_relay.regen_patches(
                prefix, patches, run, mirror if mirror.is_dir() else None
            )
        elif reset:
            brew_relay.reset_relay(prefix, run)
        elif force:
            brew_relay.force_relay(prefix, strategy, patches, run)
        else:
            brew_relay.ensure_relay_applied(prefix, strategy, patches, run)


brew_app.command(name="relay")(relay)
