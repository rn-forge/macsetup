from rn_forge.cli import ExitCode, run

from rn_forge.macsetup.main import app


def test_the_app_mounts_the_lifecycle_verbs_under_self(capsys):
    assert run(app, ["self", "--help"]) == ExitCode.OK
    out = capsys.readouterr().out
    for verb in ("install", "upgrade", "uninstall", "cleanup", "status", "doctor"):
        assert verb in out


def test_an_unknown_command_is_a_usage_error():
    assert run(app, ["nope"]) == ExitCode.USAGE
