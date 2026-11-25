"""bootstrap.sh, sourced by zsh with stubbed curl, brew, uv and uvx."""

from __future__ import annotations

import os
import re
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
BOOTSTRAP = ROOT / "bootstrap.sh"
GIT_URL = "git+https://github.com/rn-forge/macsetup"
USAGE = (
    "bootstrap: usage: . bootstrap.sh [--force] [--archive <file> --version <version>]"
)


def _stub(path: Path, body: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("#!/bin/sh\n" + body)
    path.chmod(0o755)


def _recorder(log: Path, name: str, extra: str = "") -> str:
    return f'echo "{name} $*" >> "{log}"\n{extra}'


class Run:
    def __init__(self, tmp_path: Path) -> None:
        self.tmp = tmp_path
        self.log = tmp_path / "calls.log"
        self.prefix = tmp_path / "brew"
        self.stubs = tmp_path / "stubs"
        self.home = Path(os.environ["HOME"])
        self.rnf_home = Path(os.environ["RNF_HOME"])
        self.stubs.mkdir()
        brew = self.brew_body()
        self.brew_body_text = brew
        _stub(
            self.stubs / "curl",
            _recorder(
                self.log,
                "curl",
                f"cat <<'EOS'\nmkdir -p \"{self.prefix}/bin\"\n"
                f"cat > \"{self.prefix}/bin/brew\" <<'EOB'\n#!/bin/sh\n{brew}EOB\n"
                f'chmod +x "{self.prefix}/bin/brew"\nEOS\n',
            ),
        )
        self.uvx(0)

    def brew_body(self) -> str:
        return (
            f'if [ "$1" = shellenv ]; then\n'
            f"  echo 'export PATH=\"{self.prefix}/bin:$PATH\"'\n  exit 0\nfi\n"
            + _recorder(self.log, "brew")
        )

    def uvx(self, code: int) -> None:
        _stub(self.stubs / "uvx", _recorder(self.log, "uvx", f"exit {code}\n"))

    def uv(self) -> None:
        _stub(self.stubs / "uv", _recorder(self.log, "uv"))

    def brew(self) -> None:
        _stub(self.prefix / "bin" / "brew", self.brew_body())

    def calls(self) -> list[str]:
        return self.log.read_text().splitlines() if self.log.exists() else []

    def run(self, *args: str) -> subprocess.CompletedProcess[str]:
        script = (
            f". {BOOTSTRAP} {' '.join(args)}; "
            'print -r -- "rc=$?"; print -r -- "PATH=$PATH"; '
            "typeset -f rnfmac_bootstrap >/dev/null && print leaked; print alive"
        )
        env = {
            "HOME": str(self.home),
            "RNF_HOME": str(self.rnf_home),
            "HOMEBREW_PREFIX": str(self.prefix),
            "PATH": f"{self.stubs}:/usr/bin:/bin",
        }
        return subprocess.run(
            ["zsh", "-f", "-c", script],
            check=False,
            env=env,
            capture_output=True,
            text=True,
        )


@pytest.fixture
def run(tmp_path: Path) -> Run:
    return Run(tmp_path)


def _line(result: subprocess.CompletedProcess[str], prefix: str) -> str:
    return next(x for x in result.stdout.splitlines() if x.startswith(prefix))


def test_installs_homebrew_uv_and_rnfmac(run):
    result = run.run()
    assert "rc=0" in result.stdout, result.stderr
    calls = run.calls()
    assert calls[0].startswith("curl ")
    assert "raw.githubusercontent.com/Homebrew/install/HEAD/install.sh" in calls[0]
    assert calls[1:] == [
        "brew install uv",
        f"uvx --from {GIT_URL} rnfmac self install",
    ]
    assert _line(result, "PATH=").startswith(f"PATH={run.rnf_home}/bin:")
    assert "rnfmac system init" in result.stdout + result.stderr
    assert "rnfmac sync" in result.stdout + result.stderr
    assert "leaked" not in result.stdout


def test_skips_homebrew_when_present(run):
    run.brew()
    result = run.run()
    assert "rc=0" in result.stdout, result.stderr
    assert not any(c.startswith("curl") for c in run.calls())


def test_force_reinstalls_homebrew(run):
    run.brew()
    result = run.run("--force")
    assert "rc=0" in result.stdout, result.stderr
    assert any(c.startswith("curl") for c in run.calls())


def test_skips_uv_when_present(run):
    run.brew()
    run.uv()
    result = run.run()
    assert "rc=0" in result.stdout, result.stderr
    assert "brew install uv" not in run.calls()


def test_archive_installs_from_the_file(run, tmp_path):
    run.brew()
    archive = tmp_path / "m.tar.gz"
    archive.write_text("x")
    result = run.run("--archive", str(archive), "--version", "1.2.3")
    assert "rc=0" in result.stdout, result.stderr
    assert (
        f"uvx --from {archive} rnfmac self install --archive {archive} --version 1.2.3"
        in run.calls()
    )
    assert "git+" not in run.log.read_text()


@pytest.mark.parametrize(
    "args",
    [
        ["--archive", "x"],
        ["--version", "1"],
        ["--archive"],
        ["--bogus"],
    ],
)
def test_bad_arguments_print_usage(run, args):
    result = run.run(*args)
    assert "rc=1" in result.stdout
    assert USAGE in result.stderr
    assert "alive" in result.stdout
    assert run.calls() == []


def test_missing_archive_fails_before_anything_runs(run, tmp_path):
    missing = tmp_path / "nope.tar.gz"
    result = run.run("--archive", str(missing), "--version", "1.2.3")
    assert "rc=1" in result.stdout
    assert "archive not found" in result.stderr
    assert run.calls() == []


def test_a_failed_install_returns_without_exiting(run):
    run.brew()
    run.uv()
    run.uvx(1)
    result = run.run()
    assert "rc=1" in result.stdout
    assert "bootstrap: installation failed" in result.stderr
    assert "alive" in result.stdout
    assert not _line(result, "PATH=").startswith(f"PATH={run.rnf_home}/bin")
    assert "leaked" not in result.stdout


def test_has_no_set_e_or_exit():
    lines = [
        x for x in BOOTSTRAP.read_text().splitlines() if not x.lstrip().startswith("#")
    ]
    assert not [x for x in lines if re.search(r"\bset -e\b|\bexit\b", x)]
