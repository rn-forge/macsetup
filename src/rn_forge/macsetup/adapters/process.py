"""The real runner: `subprocess` with captured output."""

from __future__ import annotations

import shutil
import subprocess
from collections.abc import Sequence
from pathlib import Path

from rn_forge.macsetup.domain.runner import NOT_FOUND, Result

__all__ = ["SubprocessRunner"]


class SubprocessRunner:
    """Runs commands on this machine."""

    def run(self, args: Sequence[str], *, cwd: Path | None = None) -> Result:
        """Run *args*, returning its exit code and decoded output."""
        try:
            done = subprocess.run(  # argv list, no shell
                list(args),
                capture_output=True,
                text=True,
                errors="replace",
                cwd=cwd,
                check=False,
            )
        except OSError as error:
            return Result(NOT_FOUND, "", str(error))
        return Result(done.returncode, done.stdout, done.stderr)

    def stream(self, args: Sequence[str], *, cwd: Path | None = None) -> int:
        """Run *args* attached to this terminal, returning its exit code."""
        try:
            return subprocess.run(
                list(args), cwd=cwd, check=False
            ).returncode  # argv list, no shell
        except OSError:
            return NOT_FOUND

    def which(self, name: str) -> bool:
        """Whether *name* is an executable on `PATH`."""
        return shutil.which(name) is not None
