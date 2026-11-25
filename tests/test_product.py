from rn_forge.commons.findings import Severity
from rn_forge.tooling.install import Link, ToolHome

from rn_forge.macsetup.product import PRODUCT


def test_the_product_keeps_its_home_apart_from_its_command():
    assert PRODUCT.name == "macsetup"
    assert ToolHome(PRODUCT.name, "/rnf").product_dir.name == "macsetup"


def test_the_artifacts_are_the_command_and_its_completion():
    assert PRODUCT.artifacts() == (
        Link("bin/rnfmac", "bin/rnfmac"),
        Link("completions/_rnfmac", "completions/_rnfmac"),
    )


def test_the_one_check_reports_the_home(tmp_path):
    (check,) = PRODUCT.checks()
    (finding,) = check(ToolHome("macsetup", tmp_path))
    assert finding.code == "macsetup.home"
    assert finding.severity is Severity.INFO
