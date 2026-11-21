"""Where the commands get their machine: the real runner and the layout from the environment.

Tests replace `runner` and `environment` here, so no command reaches a real tool.
"""

from __future__ import annotations

import os
from collections.abc import Mapping

from rn_forge.macsetup.adapters.process import SubprocessRunner
from rn_forge.macsetup.domain.layout import Layout, host_name
from rn_forge.macsetup.domain.runner import Runner

__all__ = ["environment", "host", "layout", "runner"]


def runner() -> Runner:
    """The runner commands use."""
    return SubprocessRunner()


def environment() -> Mapping[str, str]:
    """The process environment."""
    return os.environ


def layout() -> Layout:
    """The layout for the current environment."""
    return Layout.from_env(environment())


def host(run: Runner) -> str:
    """This host's short name."""
    return host_name(run)
