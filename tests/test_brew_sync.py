"""Port of tests/commands/brew/sync_spec.sh."""

from support import FakeRunner

from rn_forge.macsetup.domain.runner import Result


def test_installs_cleans_up_and_lists_against_the_host_brewfile(
    sandbox, use_runner, rnfmac
):
    runner = FakeRunner(scripts={("brew",): Result(0)})
    use_runner(runner)
    result = rnfmac("brew", "sync")
    assert result.code == 0
    file = f"--file={sandbox.config}/hosts/testhost/Brewfile"
    brew = [c for c in runner.calls if c[0] == "brew"]
    assert brew == [
        ("brew", "bundle", "install", file, "--verbose", "--force"),
        ("brew", "bundle", "cleanup", file, "--verbose", "--force"),
        ("brew", "list"),
    ]
    assert "Brew sync complete !" in result.flat


def test_a_failing_install_stops_with_its_exit_code(sandbox, use_runner, rnfmac):
    runner = FakeRunner(
        scripts={("brew",): Result(0), ("brew", "bundle", "install"): Result(1)}
    )
    use_runner(runner)
    result = rnfmac("brew", "sync")
    assert result.code == 1
    assert not any(c[:3] == ("brew", "bundle", "cleanup") for c in runner.calls)
