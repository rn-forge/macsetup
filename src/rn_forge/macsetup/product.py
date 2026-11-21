"""This tool as the lifecycle verbs see it.

`[lifecycle]` in `.rn-forge/kiln/config.toml` names `PRODUCT`; the verbs
themselves — `install`, `upgrade`, `uninstall`, `cleanup`, `status`, `doctor` —
come from `rn-forge-tooling`.

The product is `macsetup`, which names its directory under `$RNF_HOME` and keeps
`config/` and `profile.zsh` beside the tooling's `versions/`. The command it
installs is `rnfmac`. `PythonTool` derives the script, completion and links
from the product's name, so each of those steps is run as a copy of this
product named after the command.
"""

from __future__ import annotations

from collections.abc import Sequence
from dataclasses import replace
from importlib.metadata import version
from pathlib import Path

from rn_forge.commons.findings import Finding, Severity
from rn_forge.tooling.install import Check, Link, PythonTool, ToolHome

COMMAND = "rnfmac"
"""The console script this package installs."""


def check_home(home: ToolHome) -> list[Finding]:
    """Report where this tool is, or would be, installed."""
    return [
        Finding(
            "macsetup.home",
            Severity.INFO,
            f"home is {home.product_dir}",
        ),
    ]


class Tool(PythonTool):
    """`macsetup`: installed with `uv tool install`, as the command `rnfmac`."""

    def _command(self) -> PythonTool:
        """This product, named after its command."""
        return replace(self, name=COMMAND)

    def artifacts(self) -> Sequence[Link]:
        """The links ``bin/rnfmac`` and ``completions/_rnfmac``."""
        return PythonTool.artifacts(self._command())

    def build(self, release_root: Path, version_dir: Path) -> None:
        """Install the package at *release_root* into *version_dir*.

        Raises:
            AppException: ``uv tool install`` failed, or ``rnfmac`` did not print
                a zsh completion script.
        """
        PythonTool.build(self._command(), release_root, version_dir)

    def checks(self) -> Sequence[Check]:
        """Check the install's home."""
        return (check_home,)


PRODUCT = Tool(
    name="macsetup",
    version=version("rn-forge-macsetup"),
    repo="rn-forge/macsetup",
)
