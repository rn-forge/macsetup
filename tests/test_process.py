"""The real runner, against the Python interpreter running the tests (never brew)."""

import sys

from rn_forge.macsetup.adapters.process import SubprocessRunner
from rn_forge.macsetup.domain.runner import NOT_FOUND


def test_runs_a_command_and_captures_its_output(tmp_path):
    result = SubprocessRunner().run(
        [sys.executable, "-c", "import os; print(os.getcwd())"], cwd=tmp_path
    )
    assert result.ok
    assert result.stdout.strip() == str(tmp_path.resolve())


def test_a_failing_command_reports_its_code_without_raising():
    result = SubprocessRunner().run([sys.executable, "-c", "import sys; sys.exit(3)"])
    assert (result.returncode, result.ok) == (3, False)


def test_a_command_that_cannot_start_is_not_found():
    assert SubprocessRunner().run(["/nonexistent/tool"]).returncode == NOT_FOUND


def test_which_finds_only_real_executables():
    assert SubprocessRunner().which("git")
    assert not SubprocessRunner().which("rnfmac-no-such-tool")
