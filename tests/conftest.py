"""Fixtures: a sandboxed home, a local config checkout and a scripted runner.

SAFETY: `HOME` and `RNF_HOME` are overridden for every test (autouse), so a
developer's exported `RNF_HOME` can never point a test at the real home, and the
default runner cannot start `brew` or any tool but `git`.
"""

from __future__ import annotations

import os
import subprocess
from collections.abc import Callable
from pathlib import Path

import pytest
from rn_forge.cli import run as run_cli
from rn_forge.commons.runtime.console import OutputMode, console
from support import FakeRunner, Invocation, Sandbox

from rn_forge.macsetup.commands import wiring
from rn_forge.macsetup.main import app


@pytest.fixture(autouse=True)
def isolated_environment(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    """Point HOME and RNF_HOME into tmp_path and keep git hermetic."""
    home = tmp_path / "home"
    home.mkdir()
    monkeypatch.setenv("HOME", str(home))
    monkeypatch.setenv("RNF_HOME", str(home / ".rn-forge"))
    for name in (
        "ZSH_CUSTOM",
        "RNFMAC_CONFIG_REPO_URL",
        "RNF_GITHUB_ORG",
        "RNFMAC_TEST_HOMEBREW_PREFIX",
    ):
        monkeypatch.delenv(name, raising=False)
    monkeypatch.setenv("GIT_CONFIG_GLOBAL", os.devnull)
    monkeypatch.setenv("GIT_CONFIG_NOSYSTEM", "1")
    monkeypatch.setenv("GIT_TERMINAL_PROMPT", "0")
    for who in ("AUTHOR", "COMMITTER"):
        monkeypatch.setenv(f"GIT_{who}_NAME", "pytest")
        monkeypatch.setenv(f"GIT_{who}_EMAIL", "pytest@example.invalid")
    monkeypatch.setattr(wiring, "runner", lambda: FakeRunner())
    previous = console.mode
    yield
    console.set_mode(previous if isinstance(previous, OutputMode) else OutputMode.PLAIN)


@pytest.fixture
def sandbox(tmp_path: Path) -> Sandbox:
    """A home with `.zshrc`, and a config checkout cloned from a local origin."""
    home = tmp_path / "home"
    rnf_home = home / ".rn-forge"
    (home / ".oh-my-zsh" / "custom" / "themes").mkdir(parents=True)
    (home / ".zshrc").write_text("source $ZSH/oh-my-zsh.sh\n")
    seed, origin = tmp_path / "config-seed", tmp_path / "macsetup-config.git"
    (seed / "shared").mkdir(parents=True)
    (seed / "hosts" / "testhost").mkdir(parents=True)
    (seed / "shared" / "profile.zsh").write_text(
        'export RNFMAC_PROFILE_LOADED=1\necho "loading macsetup profile"\n'
    )
    (seed / "shared" / "aliases.zsh").write_text("alias rnf-test-alias='true'\n")
    (seed / "hosts" / "testhost" / "profile.zsh").write_text(
        "export RNF_TEST_HOST_MARKER=1\n"
    )
    (seed / "hosts" / "testhost" / "Brewfile").write_text(
        "# test Brewfile - intentionally empty\n"
    )
    box = Sandbox(
        tmp_path, home, rnf_home, rnf_home / "macsetup" / "config", seed, origin
    )
    box.git(tmp_path, "init", "-q", "-b", "main", str(seed))
    box.git(seed, "add", ".")
    box.git(seed, "commit", "-q", "-m", "Initial config")
    subprocess.run(["git", "init", "-q", "--bare", str(origin)], check=True)
    box.git(seed, "remote", "add", "origin", str(origin))
    box.git(seed, "push", "-q", "-u", "origin", "main")
    subprocess.run(
        ["git", "--git-dir", str(origin), "symbolic-ref", "HEAD", "refs/heads/main"],
        check=True,
    )
    box.config.parent.mkdir(parents=True)
    subprocess.run(["git", "clone", "-q", str(origin), str(box.config)], check=True)
    return box


@pytest.fixture
def use_runner(monkeypatch: pytest.MonkeyPatch) -> Callable[[FakeRunner], FakeRunner]:
    """Install a scripted runner for the commands."""

    def install(runner: FakeRunner) -> FakeRunner:
        monkeypatch.setattr(wiring, "runner", lambda: runner)
        return runner

    return install


@pytest.fixture
def rnfmac(capfd: pytest.CaptureFixture[str]) -> Callable[..., Invocation]:
    """Run the real command line and return its exit code and output."""

    def invoke(*args: str) -> Invocation:
        code = run_cli(app, list(args))
        captured = capfd.readouterr()
        return Invocation(code, captured.out, captured.err)

    return invoke
