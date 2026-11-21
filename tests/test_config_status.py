"""Ports of the `config status` examples in tests/commands/config_spec.sh.

The other examples in that spec exercise pull, push, reset and sync, which are
Phase 3 commands, so they stay with the shell until they are ported.
"""

import subprocess


def test_shows_checkout_status_and_revision(sandbox, rnfmac):
    result = rnfmac("config", "status")
    assert result.code == 0
    assert "config:" in result.out
    assert "revision:" in result.out
    assert "main" in result.out
    assert "no local changes" in result.out
    assert "up to date with origin/main" in result.out


def test_shows_a_diff_of_unpublished_changes(sandbox, rnfmac):
    with (sandbox.config / "shared" / "profile.zsh").open("a") as handle:
        handle.write("\n# local update\n")
    result = rnfmac("config", "status")
    assert result.code == 0
    assert "local changes:" in result.out
    assert "+# local update" in result.out
    assert "config push" in result.out


def test_shows_the_contents_of_untracked_config_files(sandbox, rnfmac):
    (sandbox.config / "hosts" / "testhost" / "Brewfile.new").write_text(
        'brew "ripgrep"\n'
    )
    result = rnfmac("config", "status")
    assert result.code == 0
    assert "Brewfile.new" in result.out
    assert '+brew "ripgrep"' in result.out


def test_reports_incoming_commits_without_pulling_them(sandbox, rnfmac):
    sandbox.push_remote_commit()
    result = rnfmac("config", "status")
    assert result.code == 0
    assert "behind origin/main" in result.out
    assert "Remote update" in result.out
    assert (
        "# remote update" not in (sandbox.config / "shared" / "profile.zsh").read_text()
    )


def test_an_unreachable_remote_is_reported_not_fatal(sandbox, rnfmac):
    sandbox.git(
        sandbox.config, "remote", "set-url", "origin", str(sandbox.root / "gone.git")
    )
    result = rnfmac("config", "status")
    assert result.code == 0
    assert "remote:   unreachable" in result.out


def test_a_missing_checkout_is_an_error(sandbox, rnfmac):
    subprocess.run(["rm", "-rf", str(sandbox.config)], check=True)
    result = rnfmac("config", "status")
    assert result.code == 1
    assert "macsetup config checkout is invalid" in result.flat


def test_a_checkout_on_another_branch_is_an_error(sandbox, rnfmac):
    sandbox.git(sandbox.config, "checkout", "-q", "-b", "topic")
    result = rnfmac("config", "status")
    assert result.code == 1
    assert "must be on 'main' (currently 'topic')" in result.flat


def test_a_detached_checkout_is_an_error(sandbox, rnfmac):
    sandbox.git(sandbox.config, "checkout", "-q", "--detach")
    result = rnfmac("config", "status")
    assert result.code == 1
    assert "(currently 'detached')" in result.flat
