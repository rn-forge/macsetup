"""`rnfmac system init`: install oh-my-zsh and its plugins, nvm and SDKMAN."""

from __future__ import annotations

import shutil
from collections.abc import Mapping
from pathlib import Path

from rn_forge.commons.exceptions import AppException
from rn_forge.commons.runtime.console import console

from rn_forge.macsetup.domain.layout import Layout
from rn_forge.macsetup.domain.runner import Runner
from rn_forge.macsetup.services.system_sync import shell_args

__all__ = ["system_init"]

_OHMYZSH_URL = (
    "https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"
)
_NVM_URL = "https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh"
_SDKMAN_URL = "https://get.sdkman.io?rcupdate=false"
_PLUGINS = (
    ("zsh-completions", "https://github.com/zsh-users/zsh-completions.git"),
    ("zsh-autosuggestions", "https://github.com/zsh-users/zsh-autosuggestions"),
    (
        "zsh-syntax-highlighting",
        "https://github.com/zsh-users/zsh-syntax-highlighting.git",
    ),
)


def _pipeline(runner: Runner, script: str, what: str) -> None:
    """Run a download-and-run *script* under bash with `pipefail`."""
    if runner.stream(["/bin/bash", "-c", f"set -o pipefail; {script}"]) != 0:
        raise AppException("{} installation failed", what)


def _prefix(env: Mapping[str, str], runner: Runner) -> str:
    """The Homebrew prefix: `$HOMEBREW_PREFIX`, else `brew --prefix`."""
    if env.get("HOMEBREW_PREFIX"):
        return env["HOMEBREW_PREFIX"]
    out = runner.run(["brew", "--prefix"])
    if out.ok and out.stdout.strip():
        return out.stdout.strip()
    raise AppException("cannot find Homebrew — install it before 'system init'")


def _ohmyzsh(
    layout: Layout, env: Mapping[str, str], runner: Runner, force: bool
) -> None:
    console.info("Setting up ohmyzsh ...")
    home = layout.user_home / ".oh-my-zsh"
    if home.is_dir():
        if not force:
            console.warning("oh-my-zsh available, skipping ...")
            return
        console.warning("Removing existing oh-my-zsh for reinstallation ...")
        shutil.rmtree(home)
    else:
        console.info("Installing ohmyzsh ...")
    _pipeline(
        runner,
        f'sh -c "$(curl -fsSL --proto \'=https\' --tlsv1.2 {_OHMYZSH_URL})" "" --unattended',
        "oh-my-zsh",
    )
    custom = Path(env.get("ZSH_CUSTOM") or home / "custom")
    for name, url in _PLUGINS:
        if runner.stream(["git", "clone", url, str(custom / "plugins" / name)]) != 0:
            raise AppException("cloning {} failed", name)
    console.success("oh-my-zsh setup complete ...")
    console.info("run 'rnfmac profile sync' to setup zsh environment")


def _nvm(layout: Layout, bash: str, runner: Runner, force: bool) -> None:
    console.info("Setting up nvm ...")
    home = layout.user_home / ".nvm"
    init = home / "nvm.sh"
    if home.is_dir():
        if not force:
            version = runner.run(shell_args(init, ["nvm", "--version"]))
            console.warning("`nvm {}` available, skipping ...", version.stdout.strip())
            return
        console.warning("Removing existing nvm for reinstallation ...")
        shutil.rmtree(home)
    else:
        console.info("Installing nvm ...")
    _pipeline(runner, f"curl -o- {_NVM_URL} | PROFILE=/dev/null {bash}", "nvm")
    version = runner.run(shell_args(init, ["nvm", "--version"]))
    console.success("`nvm {}` setup complete ...", version.stdout.strip())


def _sdkman_version(runner: Runner, init: Path) -> str:
    lines = runner.run(shell_args(init, ["sdk", "version"])).stdout.splitlines()
    return ";".join(" ".join(line.split()[:2]) for line in lines[2:4])


def _sdkman(layout: Layout, bash: str, runner: Runner, force: bool) -> None:
    console.info("Setting up sdkman ...")
    home = layout.user_home / ".sdkman"
    init = home / "bin" / "sdkman-init.sh"
    if init.is_file():
        if not force:
            console.warning(
                "`sdkman ({})` already installed, skipping ...",
                _sdkman_version(runner, init),
            )
            return
        console.warning("Removing existing SDKMAN installation ...")
        shutil.rmtree(home)
    else:
        console.info("Installing SDKMAN ...")
    _pipeline(runner, f'curl -s "{_SDKMAN_URL}" | {bash}', "SDKMAN")
    console.success("`sdkman ({})` setup complete ...", _sdkman_version(runner, init))


def system_init(
    layout: Layout, env: Mapping[str, str], runner: Runner, *, force: bool
) -> None:
    """Install oh-my-zsh (with plugins), nvm and SDKMAN, skipping any already present.

    Homebrew and uv are not installed here; the bootstrap provides them. With
    *force*, each component is removed and reinstalled.

    Args:
        layout: Where the user's home is.
        env: The process environment (`ZSH_CUSTOM`, `HOMEBREW_PREFIX`).
        runner: Runs the installers.
        force: Reinstall components even when present.

    Raises:
        AppException: An installer failed, or Homebrew cannot be found.
    """
    _ohmyzsh(layout, env, runner, force)
    if runner.stream(["brew", "install", "bash"]) != 0:
        raise AppException("brew install bash failed")
    bash = f"{_prefix(env, runner)}/bin/bash"
    _nvm(layout, bash, runner, force)
    _sdkman(layout, bash, runner, force)
