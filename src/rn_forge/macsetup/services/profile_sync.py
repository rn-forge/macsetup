"""`rnfmac profile sync`: render the profile, patch the rc files, install the theme and keybindings."""

from __future__ import annotations

import glob
import re
import shutil
from datetime import datetime
from pathlib import Path

from rn_forge.commons.exceptions import AppException

from rn_forge.macsetup import assets
from rn_forge.macsetup.domain.layout import Layout
from rn_forge.macsetup.domain.runner import Runner
from rn_forge.macsetup.services.profile_check import render_profile

__all__ = [
    "backup",
    "install_keybindings",
    "profile_environment",
    "profile_sync",
    "render_host_profile",
    "set_zsh_theme",
    "update_zprofile",
    "update_zshrc",
]

_OH_MY_ZSH = re.compile(rb"^source \$ZSH/oh-my-zsh\.sh")
_THEME_EXPORT = re.compile(rb"^export ZSH_THEME=(.*)$", re.MULTILINE)
_THEME_LINE = re.compile(rb"^ZSH_THEME=.*$", re.MULTILINE)


def _timestamp() -> str:
    return datetime.now().strftime("%Y%m%d%H%M%S")


def backup(layout: Layout, path: Path) -> None:
    """Back up *path* to `<rnf home>/backup/macsetup/<name>_<timestamp>`.

    Does nothing when *path* is missing or identical to the newest backup of that name.
    """
    if not path.is_file():
        return
    layout.backup_home.mkdir(parents=True, exist_ok=True)
    existing = sorted(layout.backup_home.glob(f"{glob.escape(path.name)}_*"))
    if existing and existing[-1].read_bytes() == path.read_bytes():
        return
    shutil.copyfile(path, layout.backup_home / f"{path.name}_{_timestamp()}")


def render_host_profile(layout: Layout, host: str) -> None:
    """Write the rendered `profile.zsh` and copy the host's Brewfile into the product home.

    Raises:
        AppException: The host has no profile or no Brewfile. The profile is
            already written when the Brewfile is the one missing.
    """
    host_dir = layout.config_home / "hosts" / host
    if not (host_dir / "profile.zsh").is_file():
        raise AppException(
            "no profile for host '{}' — create hosts/{}/ in macsetup-config", host, host
        )
    layout.product_home.mkdir(parents=True, exist_ok=True)
    layout.rendered_profile.write_bytes(render_profile(layout, host))
    if not (host_dir / "Brewfile").is_file():
        raise AppException(
            "no Brewfile for host '{}' — create hosts/{}/Brewfile in macsetup-config",
            host,
            host,
        )
    shutil.copyfile(host_dir / "Brewfile", layout.product_home / "Brewfile")


def _contains(path: Path, text: str) -> bool:
    try:
        return text.encode() in path.read_bytes()
    except OSError:
        return False


def update_zprofile(layout: Layout) -> None:
    """Back up and patch `~/.zprofile` to source the rendered profile.

    Appends the marker and source line, or only the source line when an older
    block has the marker alone. Creates the file when it is missing.
    """
    path = layout.user_home / ".zprofile"
    backup(layout, path)
    if not _contains(path, layout.marker):
        addition = f"{layout.marker}\n{layout.source_line}\n"
    elif not _contains(path, layout.source_line):
        addition = f"{layout.source_line}\n"
    else:
        return
    with path.open("ab") as handle:
        handle.write(addition.encode())


def update_zshrc(layout: Layout) -> None:
    """Back up `~/.zshrc` and insert the macsetup block before the oh-my-zsh source line.

    `plugins=()` must be set before oh-my-zsh reads it, so the block goes first.
    A missing `.zshrc`, or one with no such line, is left alone.
    """
    path = layout.user_home / ".zshrc"
    if not path.is_file():
        return
    backup(layout, path)
    if _contains(path, layout.marker):
        return
    block = f"{layout.marker}\n{layout.source_line}\n\n".encode()
    data = path.read_bytes()
    lines = data.split(b"\n")
    if not any(_OH_MY_ZSH.match(line) for line in lines):
        return
    if lines[-1] == b"":
        lines.pop()
    out = b"".join(
        (block if _OH_MY_ZSH.match(line) else b"") + line + b"\n" for line in lines
    )
    path.write_bytes(out)


def _install_asset(destination: Path, name: str) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.is_symlink():
        destination.unlink()
    destination.write_bytes(assets.read_asset("profiles", "shared", name))


def set_zsh_theme(layout: Layout) -> None:
    """Install the theme and set `ZSH_THEME` in `~/.zshrc` from the rendered profile."""
    _install_asset(layout.theme_destination, "rohitnarayanan.zsh-theme")
    match = _THEME_EXPORT.search(layout.rendered_profile.read_bytes())
    value = match.group(1) if match else b""
    rc = layout.user_home / ".zshrc"
    if not rc.is_file():
        return
    backup(layout, rc)
    rc.write_bytes(_THEME_LINE.sub(lambda _: b"ZSH_THEME=" + value, rc.read_bytes()))


def install_keybindings(layout: Layout) -> None:
    """Back up and install the macOS `DefaultKeyBinding.dict`."""
    backup(layout, layout.keybindings_destination)
    _install_asset(layout.keybindings_destination, "DefaultKeyBinding.dict")


def profile_sync(layout: Layout, host: str) -> None:
    """Render the profile for *host*, then apply it to the rc files, theme and keybindings.

    Raises:
        AppException: The host has no profile or Brewfile.
    """
    render_host_profile(layout, host)
    update_zprofile(layout)
    update_zshrc(layout)
    set_zsh_theme(layout)
    install_keybindings(layout)


def profile_environment(layout: Layout, runner: Runner) -> tuple[dict[str, str], str]:
    """Source the rendered profile in zsh and return the environment it leaves behind.

    Returns:
        The exported variables, and the profile's own output (stderr).

    Raises:
        AppException: Sourcing the profile failed.
    """
    result = runner.run(
        ["zsh", "-c", 'source "$1" >&2 && env -0', "_", str(layout.rendered_profile)]
    )
    if not result.ok:
        raise AppException(
            "sourcing {} failed: {}",
            layout.rendered_profile,
            result.stderr.strip(),
        )
    env: dict[str, str] = {}
    for entry in result.stdout.split("\0"):
        name, sep, value = entry.partition("=")
        if sep and name:
            env[name] = value
    return env, result.stderr
