"""The one seam to the machine: how a check runs `git`, `brew`, `hostname` and the like."""

from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass
from pathlib import Path
from typing import Protocol

__all__ = ["NOT_FOUND", "Result", "Runner"]

NOT_FOUND = 127
"""The return code of a command that could not be started, as a shell reports it."""


@dataclass(frozen=True, slots=True)
class Result:
    """What a command printed and how it ended."""

    returncode: int
    stdout: str = ""
    stderr: str = ""

    @property
    def ok(self) -> bool:
        """Whether the command exited 0."""
        return self.returncode == 0


class Runner(Protocol):
    """Runs external commands. Commands never touch `subprocess` themselves."""

    def run(self, args: Sequence[str], *, cwd: Path | None = None) -> Result:
        """Run *args* and capture its output; never raises for a failing command.

        A command that cannot be started returns `NOT_FOUND`.
        """
        ...

    def stream(self, args: Sequence[str], *, cwd: Path | None = None) -> int:
        """Run *args* with inherited stdin, stdout and stderr, so its progress shows live.

        Returns the exit code, or `NOT_FOUND` when the command cannot be started.
        """
        ...

    def which(self, name: str) -> bool:
        """Whether *name* is an executable on `PATH`."""
        ...
