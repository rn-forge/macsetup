"""Path resolution and the report's exit-code contract."""

from pathlib import Path

from support import FakeRunner

from rn_forge.macsetup.domain.layout import Layout, host_name
from rn_forge.macsetup.domain.report import Report, Status
from rn_forge.macsetup.domain.runner import Result


def test_rnf_home_defaults_to_dot_rn_forge_under_home():
    layout = Layout.from_env({"HOME": "/h"})
    assert layout.rnf_home == Path("/h/.rn-forge")
    assert layout.config_home == Path("/h/.rn-forge/macsetup/config")
    assert layout.rendered_profile == Path("/h/.rn-forge/macsetup/profile.zsh")


def test_an_empty_rnf_home_falls_back_to_the_default():
    assert Layout.from_env({"HOME": "/h", "RNF_HOME": ""}).rnf_home == Path(
        "/h/.rn-forge"
    )


def test_rnf_home_relocates_the_layout():
    layout = Layout.from_env({"HOME": "/h", "RNF_HOME": "/alt"})
    assert layout.product_home == Path("/alt/macsetup")
    assert layout.user_home == Path("/h")


def test_the_host_name_is_short_and_lower_case():
    runner = FakeRunner(scripts={("hostname",): Result(0, "Rohits-MBP.local\n")})
    assert host_name(runner) == "rohits-mbp"


def test_exit_codes_follow_the_worst_status():
    report = Report("x")
    assert report.exit_code == 0
    report.add(Status.WARNING, "c", "k", "m")
    assert (report.worst, report.exit_code) == (Status.WARNING, 0)
    report.add(Status.DRIFT, "c", "k", "m")
    assert report.exit_code == 2
    report.add(Status.ERROR, "c", "k", "m")
    assert report.exit_code == 1
