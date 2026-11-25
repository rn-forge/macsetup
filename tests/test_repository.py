"""The repository ships only the Python product: the shell product and shkit are gone."""

import importlib.metadata
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

RETIRED = [
    "shell",
    "scripts",
    ".mise.toml",
    ".shellspec",
    ".shellcheckrc",
    "VERSION",
    ".github/workflows/shell.yml",
    "tests/spec_helper.sh",
]


def test_shell_product_is_gone():
    assert [p for p in RETIRED if (ROOT / p).exists()] == []
    assert list((ROOT / "tests").rglob("*_spec.sh")) == []


def test_nothing_sources_shkit():
    tracked = subprocess.run(
        ["git", "ls-files"], cwd=ROOT, capture_output=True, text=True, check=True
    ).stdout.splitlines()
    offenders = [
        name
        for name in tracked
        if not name.startswith("docs/specs/")
        and name != "tests/test_repository.py"
        and (ROOT / name).is_file()
        and "shkit.sh" in (ROOT / name).read_text(errors="ignore")
    ]
    assert offenders == []


def test_version_is_3_0_0():
    assert importlib.metadata.version("rn-forge-macsetup") == "3.0.0"
