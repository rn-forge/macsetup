"""The top-level `rnfmac sync`: config, profile, then brew and system."""

from __future__ import annotations

from rn_forge.commons.runtime.console import console

from rn_forge.macsetup.commands import brew, config, output, profile, system, wiring
from rn_forge.macsetup.services.profile_sync import profile_environment

__all__ = ["sync"]


def sync() -> None:
    """Pull the config, sync the profile, then sync Homebrew packages and runtimes.

    When the config checkout did not exist, it is cloned and nothing is applied.
    Set RNFMAC_SYNC_PROFILES_ONLY to stop after the profile.
    """
    layout = wiring.layout()
    existed = layout.config_home.exists()
    config.pull()
    if not existed:
        console.info(
            "configuration checkout created but not applied — run 'rnfmac sync' to apply it"
        )
        return
    profile.sync()
    env, messages = profile_environment(layout, wiring.runner())
    if messages.strip():
        output.say(messages.rstrip("\n"))
    wiring.apply_environment(env)
    if wiring.environment().get("RNFMAC_SYNC_PROFILES_ONLY"):
        console.info("RNFMAC_SYNC_PROFILES_ONLY set — skipping brew and system sync")
        return
    brew.sync()
    system.sync()
