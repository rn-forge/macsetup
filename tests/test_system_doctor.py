"""Ports of tests/commands/system/doctor_spec.sh, plus the branches that spec left to the shell."""

import json
import shutil

from support import FakeRunner, brew_script

from rn_forge.macsetup.domain.runner import Result


def healthy(sandbox, use_runner) -> FakeRunner:
    sandbox.install_layout()
    sandbox.install_toolchain()
    prefix = sandbox.root / "homebrew-test"
    prefix.mkdir()
    sandbox.git(sandbox.root, "init", "-q", "-b", "main", str(prefix))
    sandbox.git(prefix, "commit", "-q", "--allow-empty", "-m", "initial")
    scripts = {
        **brew_script(prefix=str(prefix)),
        ("uv", "--version"): Result(0, "uv 0.4.0\n"),
    }
    return use_runner(FakeRunner(tools=("brew", "uv"), scripts=scripts))


def test_hides_healthy_records_by_default(sandbox, use_runner, rnfmac):
    healthy(sandbox, use_runner)
    result = rnfmac("system", "doctor")
    assert result.code == 0
    assert "Homebrew 4.1.0" not in result.out
    assert "nvm present" not in result.out
    assert "macsetup current ->" not in result.out
    assert "13 ok, 0 warning, 0 drift, 0 error" in result.out


def test_all_includes_healthy_records(sandbox, use_runner, rnfmac):
    healthy(sandbox, use_runner)
    result = rnfmac("system", "doctor", "--all")
    assert result.code == 0
    for text in (
        "Homebrew 4.1.0",
        "oh-my-zsh plugin 'zsh-completions' present",
        "oh-my-zsh present",
        "uv 0.4.0",
        "nvm present",
        "sdkman present",
        "macsetup current ->",
        "bin/rnfmac linked",
        "completions/_rnfmac linked",
        "shkit installed and sourceable",
        "Homebrew is on a clean base",
    ):
        assert text in result.out


def test_exits_2_when_configured_state_has_drifted(sandbox, use_runner, rnfmac):
    healthy(sandbox, use_runner)
    shutil.rmtree(sandbox.home / ".nvm")
    result = rnfmac("system", "doctor")
    assert result.code == 2
    assert "nvm not found" in result.err
    assert "12 ok, 0 warning, 1 drift, 0 error" in result.out


def test_exits_1_when_the_runtime_layout_is_broken(sandbox, use_runner, rnfmac):
    # the spec removed shkit.sh from an installed layout; here nothing is installed,
    # so current, bin/rnfmac and shkit are errors and the completion link is drift
    healthy(sandbox, use_runner)
    (sandbox.rnf_home / "shkit" / "current" / "shkit.sh").unlink()
    (sandbox.rnf_home / "bin" / "rnfmac").unlink()
    (sandbox.rnf_home / "macsetup" / "current").unlink()
    (sandbox.rnf_home / "completions" / "_rnfmac").unlink()
    result = rnfmac("system", "doctor")
    assert result.code == 1
    assert "shkit not found at" in result.flat
    assert "9 ok, 0 warning, 1 drift, 3 error" in result.out


def test_reports_a_relay_patched_homebrew_with_all(sandbox, use_runner, rnfmac):
    healthy(sandbox, use_runner)
    prefix = sandbox.root / "homebrew-test"
    sandbox.git(
        prefix,
        "commit",
        "-q",
        "--allow-empty",
        "-m",
        "rn-forge: apply Homebrew remote relay",
    )
    result = rnfmac("system", "doctor", "--all")
    assert result.code == 0
    assert "Homebrew is patched with the remote relay" in result.out


def test_help_describes_the_command(rnfmac):
    result = rnfmac("system", "doctor", "--help")
    assert result.code == 0
    assert "system doctor" in result.out
    assert "--all" in result.out
    assert "--json" in result.out


def test_a_missing_homebrew_is_an_error_and_skips_the_plugin_checks(
    sandbox, use_runner, rnfmac
):
    sandbox.install_layout()
    use_runner(FakeRunner())
    result = rnfmac("system", "doctor")
    assert result.code == 1
    assert "homebrew not found" in result.flat
    assert "omz-plugin" not in result.out
    assert "uv not found" in result.err


def test_a_missing_plugin_is_drift(sandbox, use_runner, rnfmac):
    healthy(sandbox, use_runner)
    shutil.rmtree(
        sandbox.home / ".oh-my-zsh" / "custom" / "plugins" / "zsh-autosuggestions"
    )
    result = rnfmac("system", "doctor")
    assert result.code == 2
    assert "oh-my-zsh plugin 'zsh-autosuggestions' missing" in result.flat


def test_zsh_custom_relocates_the_plugin_directory(
    sandbox, use_runner, rnfmac, monkeypatch
):
    healthy(sandbox, use_runner)
    shutil.rmtree(sandbox.home / ".oh-my-zsh" / "custom")
    custom = sandbox.root / "custom"
    for plugin in ("zsh-completions", "zsh-autosuggestions", "zsh-syntax-highlighting"):
        (custom / "plugins" / plugin).mkdir(parents=True)
    monkeypatch.setenv("ZSH_CUSTOM", str(custom))
    assert rnfmac("system", "doctor").code == 0


def test_relay_state_is_skipped_when_the_prefix_is_not_a_git_repo(
    sandbox, use_runner, rnfmac
):
    sandbox.install_layout()
    sandbox.install_toolchain()
    use_runner(
        FakeRunner(
            tools=("brew", "uv"),
            scripts={
                **brew_script(prefix=str(sandbox.root / "nowhere")),
                ("uv", "--version"): Result(0, "uv 0.4.0\n"),
            },
        )
    )
    result = rnfmac("system", "doctor", "--all")
    assert result.code == 0
    assert "relay" not in result.out
    assert "12 ok" in result.out


def test_json_reports_findings_with_their_macsetup_status(sandbox, use_runner, rnfmac):
    healthy(sandbox, use_runner)
    shutil.rmtree(sandbox.home / ".nvm")
    result = rnfmac("system", "doctor", "--json")
    assert result.code == 2
    payload = json.loads(result.out)
    nvm = next(f for f in payload["findings"] if f["code"] == "system.nvm")
    assert nvm["details"] == {
        "status": "drift",
        "group": "system",
        "category": "toolchain",
    }
    assert payload["summary"] == {"error": 0, "drift": 1, "warning": 0, "ok": 12}
