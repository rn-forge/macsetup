"""Port of tests/commands/brew/relay_spec.sh."""

import shutil
import subprocess
from pathlib import Path

import pytest
from support import FakeRunner

from rn_forge.macsetup.domain.runner import Result
from rn_forge.macsetup.services import brew_relay

MANAGED = (
    "Library/Homebrew/download_strategy.rb",
    "Library/Homebrew/download_strategy/download_strategy_detector.rb",
    "Library/Homebrew/cmd/vendor-install.sh",
)
STRATEGY = "Library/Homebrew/download_strategy/remote_relay_curl_download_strategy.rb"
SUBJECT = "rn-forge: apply Homebrew remote relay"
REPO_ROOT = Path(__file__).resolve().parent.parent
PACKAGED = REPO_ROOT / "src" / "rn_forge" / "macsetup" / "assets" / "homebrew"


def git(repo: Path, *args: str) -> str:
    return subprocess.run(
        ["git", "-C", str(repo), *args], capture_output=True, text=True, check=True
    ).stdout


@pytest.fixture
def prefix(tmp_path, monkeypatch) -> Path:
    """A fake Homebrew repo with the three managed files and one baseline commit."""
    repo = tmp_path / "homebrew"
    for managed in MANAGED:
        (repo / managed).parent.mkdir(parents=True, exist_ok=True)
        (repo / managed).write_text(f"original: {managed}\n")
    subprocess.run(["git", "init", "-q", "-b", "main", str(repo)], check=True)
    git(repo, "add", ".")
    git(repo, "commit", "-q", "-m", "baseline")
    monkeypatch.setenv("RNFMAC_TEST_HOMEBREW_PREFIX", str(repo))
    return repo


@pytest.fixture
def runner(use_runner) -> FakeRunner:
    return use_runner(FakeRunner(scripts={("brew", "update"): Result(0)}))


def assert_clean_base(repo: Path) -> None:
    for managed in MANAGED:
        assert (repo / managed).read_text() == f"original: {managed}\n"
    assert not (repo / STRATEGY).exists()
    assert git(repo, "log", "-1", "--pretty=%s").strip() == "baseline"


def test_rejects_force_with_reset(prefix, runner, rnfmac):
    assert rnfmac("brew", "relay", "--force", "--reset").code == 2


def test_a_missing_prefix_is_an_error(prefix, runner, rnfmac, tmp_path, monkeypatch):
    monkeypatch.setenv("RNFMAC_TEST_HOMEBREW_PREFIX", str(tmp_path / "nowhere"))
    result = rnfmac("brew", "relay")
    assert result.code == 1
    assert "not compatible with the Homebrew relay" in result.flat


def test_a_prefix_inside_another_repo_is_refused(prefix, runner, rnfmac, monkeypatch):
    nested = prefix / "Library"
    monkeypatch.setenv("RNFMAC_TEST_HOMEBREW_PREFIX", str(nested))
    result = rnfmac("brew", "relay", "--reset")
    assert result.code == 1
    assert "is not the root of its git repository" in result.flat


def test_reset_restores_managed_files_and_removes_the_strategy(prefix, runner, rnfmac):
    (prefix / MANAGED[0]).write_text("edited\n")
    (prefix / STRATEGY).write_text("strategy\n")
    result = rnfmac("brew", "relay", "--reset")
    assert result.code == 0
    assert_clean_base(prefix)
    assert "homebrew remote_relay removed" in result.flat


def test_conflicts_reset_to_the_clean_base(prefix, runner, rnfmac):
    result = rnfmac("brew", "relay")
    assert result.code == 1
    assert "reset Homebrew back to its clean base" in result.flat
    assert_clean_base(prefix)


def test_already_applied_is_a_no_op(prefix, runner, rnfmac):
    git(prefix, "commit", "-q", "--allow-empty", "-m", SUBJECT)
    result = rnfmac("brew", "relay")
    assert result.code == 0
    assert "already applied" in result.flat
    assert git(prefix, "log", "-1", "--pretty=%s").strip() == SUBJECT


def test_force_reapplies_even_when_applied(prefix, runner, rnfmac):
    git(prefix, "commit", "-q", "--allow-empty", "-m", SUBJECT)
    result = rnfmac("brew", "relay", "--force")
    assert ("brew", "update") in runner.calls
    assert result.code == 1
    assert "reset Homebrew back to its clean base" in result.flat


def test_regen_then_apply_round_trips(prefix, runner, tmp_path, rnfmac):
    payload = tmp_path / "payload"
    shutil.copytree(PACKAGED, payload)
    for managed in MANAGED:
        (prefix / managed).write_text(f"edited: {managed}\n")
    brew_relay.regen_patches(prefix, payload / "patches", runner)
    for managed in MANAGED:
        assert (payload / "patches" / f"{Path(managed).name}.patch").stat().st_size > 0
    git(prefix, "reset", "-q", "--hard")
    brew_relay.apply_relay(
        prefix,
        payload / "download_strategy" / Path(STRATEGY).name,
        payload / "patches",
        runner,
    )
    assert git(prefix, "log", "-1", "--pretty=%s").strip() == SUBJECT
    for managed in MANAGED:
        assert (prefix / managed).read_text() == f"edited: {managed}\n"
    assert STRATEGY in git(prefix, "show", "--name-only", "--pretty=", "HEAD")


def test_regen_refuses_a_relay_head(prefix, runner, tmp_path):
    git(prefix, "commit", "-q", "--allow-empty", "-m", SUBJECT)
    with pytest.raises(Exception, match="HEAD is the relay commit"):
        brew_relay.regen_patches(prefix, tmp_path, runner)


def test_regen_requires_a_checkout(runner, tmp_path):
    outside = tmp_path / "outside"
    outside.mkdir()
    with pytest.raises(Exception, match="requires a git checkout"):
        brew_relay.checkout_root(outside, runner)
