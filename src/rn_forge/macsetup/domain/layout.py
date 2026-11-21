"""Where macsetup keeps things: the rn-forge home, the product directory and the config checkout."""

from __future__ import annotations

from collections.abc import Mapping
from dataclasses import dataclass
from pathlib import Path

from rn_forge.macsetup.domain.runner import Runner

__all__ = ["CONFIG_BRANCH", "Layout", "host_name"]

CONFIG_BRANCH = "main"
"""The only branch the config checkout may be on."""


@dataclass(frozen=True, slots=True)
class Layout:
    """The paths a command reads, derived from `$HOME` and `$RNF_HOME`."""

    user_home: Path
    rnf_home: Path

    @classmethod
    def from_env(cls, env: Mapping[str, str]) -> Layout:
        """Resolve the layout: `$RNF_HOME`, or `~/.rn-forge` when it is unset or empty."""
        user_home = Path(env.get("HOME") or Path.home())
        return cls(user_home, Path(env.get("RNF_HOME") or user_home / ".rn-forge"))

    @property
    def product_home(self) -> Path:
        """`<rnf home>/macsetup`."""
        return self.rnf_home / "macsetup"

    @property
    def config_home(self) -> Path:
        """The persistent macsetup-config checkout."""
        return self.product_home / "config"

    @property
    def rendered_profile(self) -> Path:
        """The `profile.zsh` that `profile sync` renders."""
        return self.product_home / "profile.zsh"

    @property
    def marker(self) -> str:
        """The marker line that opens macsetup's block in an rc file."""
        return "#################### macsetup"

    @property
    def source_line(self) -> str:
        """The line an rc file uses to source the rendered profile."""
        return f"source {self.rendered_profile}"


def host_name(runner: Runner) -> str:
    """This host's short, lower-case name, as `hostname | tr A-Z a-z | cut -d. -f1`."""
    out = runner.run(["hostname"]).stdout.strip().lower()
    return out.split(".")[0]
