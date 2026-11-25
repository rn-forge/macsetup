"""Ports of the pull, push and reset examples in tests/commands/config_spec.sh."""

import subprocess

PROFILE = ("shared", "profile.zsh")
BREWFILE = ("hosts", "testhost", "Brewfile")


def append(sandbox, parts, text):
    with sandbox.config.joinpath(*parts).open("a") as handle:
        handle.write(text)


def origin_log(sandbox, fmt="%s"):
    return sandbox.git(sandbox.origin, "log", f"--format={fmt}").splitlines()


def test_pull_fast_forwards_a_new_remote_commit(sandbox, rnfmac):
    sandbox.push_remote_commit()
    result = rnfmac("config", "pull")
    assert result.code == 0
    assert "macsetup config is current" in result.flat
    assert "# remote update" in sandbox.config.joinpath(*PROFILE).read_text()


def test_pull_preserves_uncommitted_local_changes(sandbox, rnfmac):
    sandbox.push_remote_commit()
    append(sandbox, BREWFILE, "\n# local update\n")
    result = rnfmac("config", "pull")
    assert result.code == 0
    assert "# remote update" in sandbox.config.joinpath(*PROFILE).read_text()
    assert "# local update" in sandbox.config.joinpath(*BREWFILE).read_text()
    assert "local config changes are still unpublished" in result.flat
    assert sandbox.git(sandbox.config, "stash", "list") == ""


def test_pull_refuses_a_divergent_checkout(sandbox, rnfmac):
    append(sandbox, PROFILE, "\n# local commit\n")
    sandbox.git(sandbox.config, "commit", "-qam", "Local commit")
    sandbox.push_remote_commit()
    result = rnfmac("config", "pull")
    assert result.code == 1
    assert "local commits that are not on origin/main" in result.flat


def test_pull_clones_an_absent_checkout(sandbox, rnfmac, monkeypatch):
    subprocess.run(["rm", "-rf", str(sandbox.config)], check=True)
    monkeypatch.setenv("RNFMAC_CONFIG_REPO_URL", str(sandbox.origin))
    result = rnfmac("config", "pull")
    assert result.code == 0
    assert sandbox.git(sandbox.config, "branch", "--show-current").strip() == "main"


def test_push_defaults_the_message_to_the_host_name(sandbox, rnfmac):
    append(sandbox, PROFILE, "\n# published update\n")
    result = rnfmac("config", "push")
    assert result.code == 0
    assert "macsetup config published" in result.flat
    assert origin_log(sandbox)[0] == "testhost"


def test_push_uses_the_given_message(sandbox, rnfmac):
    append(sandbox, PROFILE, "\n# one\n")
    assert rnfmac("config", "push", "--message", "hello").code == 0
    assert origin_log(sandbox)[0] == "hello"


def test_push_rejects_an_empty_message(sandbox, rnfmac):
    append(sandbox, PROFILE, "\n# published update\n")
    result = rnfmac("config", "push", "--message", "")
    assert result.code == 1
    assert origin_log(sandbox) == ["Initial config"]
    assert sandbox.git(sandbox.config, "status", "--porcelain").strip() != ""


def test_push_with_no_changes_is_an_error(sandbox, rnfmac):
    result = rnfmac("config", "push")
    assert result.code == 1
    assert "no changes to publish" in result.flat


def test_push_lands_on_a_remote_that_moved_on(sandbox, rnfmac):
    sandbox.push_remote_commit()
    append(sandbox, BREWFILE, "\n# published update\n")
    result = rnfmac("config", "push", "--message", "Publish test config")
    assert result.code == 0
    assert origin_log(sandbox) == [
        "Publish test config",
        "Remote update",
        "Initial config",
    ]
    assert sandbox.git(sandbox.origin, "rev-list", "--merges", "main").strip() == ""


def test_reset_refuses_without_force(sandbox, rnfmac):
    append(sandbox, PROFILE, "\n# local update\n")
    result = rnfmac("config", "reset")
    assert result.code == 1
    assert "rerun with --force" in result.flat
    assert "profile.zsh" in result.out
    assert "# local update" in sandbox.config.joinpath(*PROFILE).read_text()


def test_reset_force_discards_tracked_and_untracked_changes(sandbox, rnfmac):
    append(sandbox, PROFILE, "\n# local update\n")
    untracked = sandbox.config / "hosts" / "testhost" / "Brewfile.new"
    untracked.write_text('brew "ripgrep"\n')
    result = rnfmac("config", "reset", "--force")
    assert result.code == 0
    assert "macsetup config reset to origin/main" in result.flat
    assert "# local update" not in sandbox.config.joinpath(*PROFILE).read_text()
    assert not untracked.exists()


def test_reset_is_a_no_op_when_clean(sandbox, rnfmac):
    result = rnfmac("config", "reset")
    assert result.code == 0
    assert "already clean" in result.flat
