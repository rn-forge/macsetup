"""Ports of tests/commands/doctor_spec.sh: the meta sweep across system, profile and brew."""

import json

from support import FakeRunner, brew_script

from rn_forge.macsetup.domain.runner import Result


def sweep(sandbox, use_runner, **brew):
    sandbox.install_layout()
    use_runner(
        FakeRunner(
            tools=("brew",),
            scripts=brew_script(prefix=str(sandbox.root / "homebrew-test"), **brew),
        )
    )


def test_renders_one_combined_report_and_exits_2_when_any_group_has_drift(
    sandbox, use_runner, rnfmac
):
    sweep(sandbox, use_runner)
    result = rnfmac("doctor")
    assert result.code == 2
    assert "nvm not found" in result.flat
    assert result.out.count(" ok, ") == 1
    for heading in ("toolchain", "runtime", "profile", "packages"):
        assert result.out.splitlines().count(heading) == 1


def test_json_emits_only_aggregated_records(sandbox, use_runner, rnfmac):
    sweep(sandbox, use_runner)
    result = rnfmac("doctor", "--json")
    assert result.code == 2
    payload = json.loads(result.out)
    assert {f["details"]["group"] for f in payload["findings"]} == {
        "system",
        "profile",
        "brew",
    }
    assert all("status" in f["details"] for f in payload["findings"])
    assert "[info]" not in result.out


def test_help_describes_the_command(rnfmac):
    result = rnfmac("doctor", "--help")
    assert result.code == 0
    assert "doctor" in result.out
    assert "--all" in result.out
    assert "--json" in result.out


def test_brew_detail_is_not_shown_in_the_combined_report(sandbox, use_runner, rnfmac):
    # the shell ran brew diff in raw mode, which hid brew's stdout but let its stderr through
    sweep(sandbox, use_runner, missing=True)
    result = rnfmac("doctor")
    assert "missing package from Brewfile" not in result.out
    assert "packages from the Brewfile are missing" in result.flat


def test_a_broken_layout_makes_the_sweep_exit_1(sandbox, use_runner, rnfmac):
    use_runner(
        FakeRunner(
            tools=("brew",),
            scripts={**brew_script(), ("hostname",): Result(0, "Testhost.local\n")},
        )
    )
    result = rnfmac("doctor")
    assert result.code == 1
    assert "no rendered profile at" in result.flat
