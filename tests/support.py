"""Test doubles and helpers shared by the command tests (importable; conftest holds the fixtures)."""

from __future__ import annotations

import subprocess
from collections.abc import Callable, Sequence
from dataclasses import dataclass
from pathlib import Path

from rn_forge.macsetup.adapters.process import SubprocessRunner
from rn_forge.macsetup.domain.runner import NOT_FOUND, Result

Script = Result | Callable[[Sequence[str]], Result]


class FakeRunner:
    """A runner that scripts `brew`, `uv` and `hostname`, and runs real `git`.

    Anything that is neither scripted nor `git` fails as "not found", so a test
    can never reach a real Homebrew.
    """

    def __init__(
        self,
        tools: Sequence[str] = (),
        scripts: dict[tuple[str, ...], Script] | None = None,
    ) -> None:
        self.tools = set(tools)
        self.scripts: dict[tuple[str, ...], Script] = {
            ("hostname",): Result(0, "testhost\n")
        }
        self.scripts.update(scripts or {})
        self.calls: list[tuple[str, ...]] = []
        self._git = SubprocessRunner()

    def run(self, args: Sequence[str], *, cwd: Path | None = None) -> Result:
        self.calls.append(tuple(args))
        for size in range(len(args), 0, -1):
            script = self.scripts.get(tuple(args[:size]))
            if script is not None:
                return script(args) if callable(script) else script
        if args[0] == "git":
            return self._git.run(args, cwd=cwd)
        return Result(NOT_FOUND, "", f"{args[0]}: not found")

    def stream(self, args: Sequence[str], *, cwd: Path | None = None) -> int:
        self.calls.append(tuple(args))
        for size in range(len(args), 0, -1):
            script = self.scripts.get(tuple(args[:size]))
            if script is not None:
                return (script(args) if callable(script) else script).returncode
        if args[0] == "git":
            return self._git.run(args, cwd=cwd).returncode
        return NOT_FOUND

    def which(self, name: str) -> bool:
        return name in self.tools


@dataclass
class Sandbox:
    """A fake `$HOME` with a seeded config origin and a checkout of it."""

    root: Path
    home: Path
    rnf_home: Path
    config: Path
    seed: Path
    origin: Path

    def git(self, repo: Path, *args: str) -> str:
        done = subprocess.run(
            ["git", "-C", str(repo), *args], capture_output=True, text=True, check=True
        )
        return done.stdout

    def push_remote_commit(self) -> None:
        """Advance the origin by one commit, so the checkout is behind it."""
        with (self.seed / "shared" / "profile.zsh").open("a") as handle:
            handle.write("\n# remote update\n")
        self.git(self.seed, "add", "shared/profile.zsh")
        self.git(self.seed, "commit", "-m", "Remote update")
        self.git(self.seed, "push", "origin", "main")

    def install_layout(self) -> None:
        """Lay out an installed macsetup and shkit, as `install.sh` would."""
        product = self.rnf_home / "macsetup"
        (product / "v1").mkdir(parents=True, exist_ok=True)
        (product / "v1" / "rnfmac.sh").write_text("")
        (product / "current").symlink_to("v1")
        (self.rnf_home / "bin").mkdir(exist_ok=True)
        (self.rnf_home / "bin" / "rnfmac").symlink_to(product / "current" / "rnfmac.sh")
        (self.rnf_home / "completions").mkdir(exist_ok=True)
        (self.rnf_home / "completions" / "_rnfmac").symlink_to(
            product / "current" / "rnfmac.sh"
        )
        (self.rnf_home / "shkit" / "v1").mkdir(parents=True, exist_ok=True)
        (self.rnf_home / "shkit" / "v1" / "shkit.sh").write_text("")
        (self.rnf_home / "shkit" / "current").symlink_to("v1")

    def install_toolchain(self) -> None:
        """Create the oh-my-zsh plugins, nvm and sdkman directories."""
        for plugin in (
            "zsh-completions",
            "zsh-autosuggestions",
            "zsh-syntax-highlighting",
        ):
            (self.home / ".oh-my-zsh" / "custom" / "plugins" / plugin).mkdir(
                parents=True, exist_ok=True
            )
        (self.home / ".nvm").mkdir(exist_ok=True)
        (self.home / ".sdkman" / "bin").mkdir(parents=True, exist_ok=True)
        (self.home / ".sdkman" / "bin" / "sdkman-init.sh").write_text("")


@dataclass
class Invocation:
    code: int
    out: str
    err: str

    @property
    def flat(self) -> str:
        """stdout and stderr with runs of whitespace collapsed, so wrapping cannot hide a phrase."""
        return " ".join((self.out + "\n" + self.err).split())


def brew_script(
    version: str = "Homebrew 4.1.0",
    prefix: str = "",
    *,
    missing: bool = False,
    extras: str = "",
) -> dict[tuple[str, ...], Script]:
    """Scripted `brew`: version, prefix, and a `bundle check`/`cleanup` that report drift on request."""
    return {
        ("brew", "--version"): Result(
            0, f"{version}\nHomebrew/homebrew-core (git revision abc)\n"
        ),
        ("brew", "--prefix"): Result(0, f"{prefix}\n"),
        ("brew", "bundle", "check"): Result(1, "missing package from Brewfile\n")
        if missing
        else Result(0, "The Brewfile's dependencies are satisfied.\n"),
        ("brew", "bundle", "cleanup"): Result(0, extras),
    }
