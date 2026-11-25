"""Port of tests/commands/sync_spec.sh and the sync case of config_spec.sh."""

import shutil

from support import FakeRunner

from rn_forge.macsetup.domain.runner import Result

PROFILE = "PATH=/x\0RNFMAC_PROFILE_LOADED=1\0"


def scripted(zsh: Result | None = None) -> FakeRunner:
    zsh = zsh or Result(0, PROFILE, "loading macsetup profile\n")
    return FakeRunner(scripts={("zsh",): zsh, ("brew",): Result(0), ("uv",): Result(0)})


def seed_versions(sandbox) -> None:
    """Write the runtime pins into the checkout directly (they stay local changes)."""
    shared = sandbox.config / "shared"
    (shared / "python-versions").write_text("3.13\n")
    (shared / "node-versions").write_text("22\n")
    (shared / "java-versions").write_text("21.0.5-tem\n")


def test_runs_every_step_in_order(sandbox, use_runner, rnfmac, applied_environment):
    seed_versions(sandbox)
    runner = use_runner(scripted())
    result = rnfmac("sync")
    assert result.code == 0
    calls = runner.calls
    fetch = next(i for i, c in enumerate(calls) if c[0] == "git" and "fetch" in c)
    zsh = next(i for i, c in enumerate(calls) if c[0] == "zsh")
    brew = next(
        i for i, c in enumerate(calls) if c[:3] == ("brew", "bundle", "install")
    )
    uv = next(i for i, c in enumerate(calls) if c[:3] == ("uv", "python", "install"))
    assert fetch < zsh < brew < uv
    assert "Profile synced successfully" in result.flat
    assert "System sync complete" in result.flat
    assert "loading macsetup profile" in result.flat
    assert applied_environment[0]["RNFMAC_PROFILE_LOADED"] == "1"


def test_profiles_only_skips_brew_and_system_sync(
    sandbox, use_runner, rnfmac, applied_environment, monkeypatch
):
    monkeypatch.setenv("RNFMAC_SYNC_PROFILES_ONLY", "1")
    runner = use_runner(scripted())
    result = rnfmac("sync")
    assert result.code == 0
    assert "loading macsetup profile" in result.flat
    assert "skipping brew and system sync" in result.flat
    assert not any(c[0] in ("brew", "uv") for c in runner.calls)


def test_an_absent_checkout_is_cloned_but_not_applied(
    sandbox, use_runner, rnfmac, applied_environment, monkeypatch
):
    shutil.rmtree(sandbox.config)
    monkeypatch.setenv("RNFMAC_CONFIG_REPO_URL", str(sandbox.origin))
    runner = use_runner(scripted())
    result = rnfmac("sync")
    assert result.code == 0
    assert "configuration checkout created but not applied" in result.flat
    assert (sandbox.config / ".git").exists()
    assert not (sandbox.rnf_home / "macsetup" / "profile.zsh").exists()
    assert not any(c[0] in ("brew", "zsh") for c in runner.calls)


def test_keeps_uncommitted_config_changes(
    sandbox, use_runner, rnfmac, applied_environment
):
    seed_versions(sandbox)
    brewfile = sandbox.config / "hosts" / "testhost" / "Brewfile"
    with brewfile.open("a") as handle:
        handle.write("# local update\n")
    use_runner(scripted())
    result = rnfmac("sync")
    assert result.code == 0
    assert "macsetup config is current" in result.flat
    assert "# local update" in brewfile.read_text()


def test_a_failing_profile_source_stops_the_sync(
    sandbox, use_runner, rnfmac, applied_environment
):
    runner = use_runner(scripted(Result(1, "", "boom")))
    result = rnfmac("sync")
    assert result.code == 1
    assert "boom" in result.flat
    assert not any(c[0] == "brew" for c in runner.calls)
