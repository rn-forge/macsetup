"""Ports of tests/commands/brew/diff_spec.sh, and the awk dedupe as a plain function."""

import json
import shutil

import pytest
from rn_forge.commons.exceptions import AppException
from support import FakeRunner, brew_script

from rn_forge.macsetup.domain.brewfile import dedupe_brewfile
from rn_forge.macsetup.domain.layout import Layout
from rn_forge.macsetup.domain.runner import Result
from rn_forge.macsetup.services.brew_diff import brewfile_path


def dump_script(target_text: str = 'brew "git"\nbrew "shellcheck"\nbrew "libdep"\n'):
    def dump(args):
        target = next(a for a in args if a.startswith("--file=")).removeprefix(
            "--file="
        )
        with open(target, "w") as handle:
            handle.write(target_text)
        return Result(0)

    return {
        ("brew", "bundle", "dump"): dump,
        ("brew", "list", "--formula", "--installed-on-request"): Result(
            0, "git\nshellcheck\n"
        ),
    }


def test_help_prints_usage_and_exits_0(rnfmac):
    result = rnfmac("brew", "diff", "--help")
    assert result.code == 0
    assert "brew diff" in result.out
    assert "--write" in result.out


def test_an_unrecognized_flag_is_a_usage_error(rnfmac):
    # the shell exited 1 with its own usage line; the CLI framework reports usage errors as 2
    result = rnfmac("brew", "diff", "--bogus")
    assert result.code == 2
    assert "No such option: --bogus" in result.err


def test_write_fails_when_the_checkout_is_missing(sandbox, use_runner, rnfmac):
    use_runner(FakeRunner(tools=("brew",), scripts=dump_script()))
    shutil.rmtree(sandbox.config)
    result = rnfmac("brew", "diff", "--write")
    assert result.code == 1
    assert "macsetup config checkout is missing" in result.flat


def test_write_updates_the_host_brewfile_and_drops_dependency_formulae(
    sandbox, use_runner, rnfmac
):
    use_runner(FakeRunner(tools=("brew",), scripts=dump_script()))
    result = rnfmac("brew", "diff", "--write")
    assert result.code == 0
    assert "Brewfile updated" in result.flat
    brewfile = (sandbox.config / "hosts" / "testhost" / "Brewfile").read_text()
    assert 'brew "git"' in brewfile
    assert 'brew "shellcheck"' in brewfile
    assert "libdep" not in brewfile


def test_write_fails_when_brew_dump_fails(sandbox, use_runner, rnfmac):
    use_runner(
        FakeRunner(
            tools=("brew",), scripts={("brew", "bundle", "dump"): Result(1, "", "boom")}
        )
    )
    result = rnfmac("brew", "diff", "--write")
    assert result.code == 1
    assert "brew bundle dump failed: boom" in result.flat


def test_write_fails_when_brew_list_fails(sandbox, use_runner, rnfmac):
    scripts = {
        **dump_script(),
        ("brew", "list", "--formula", "--installed-on-request"): Result(1, "", "nope"),
    }
    use_runner(FakeRunner(tools=("brew",), scripts=scripts))
    result = rnfmac("brew", "diff", "--write")
    assert result.code == 1
    assert "brew list failed: nope" in result.flat


def test_hides_a_healthy_result_by_default(sandbox, use_runner, rnfmac):
    use_runner(FakeRunner(tools=("brew",), scripts=brew_script()))
    result = rnfmac("brew", "diff")
    assert result.code == 0
    assert "no drift" not in result.out
    assert "1 ok, 0 warning, 0 drift, 0 error" in result.out


def test_all_includes_the_healthy_result(sandbox, use_runner, rnfmac):
    use_runner(FakeRunner(tools=("brew",), scripts=brew_script()))
    result = rnfmac("brew", "diff", "--all")
    assert result.code == 0
    assert "no drift — installed packages match the Brewfile" in result.out


def test_exits_2_and_preserves_brew_detail_in_human_output(sandbox, use_runner, rnfmac):
    use_runner(FakeRunner(tools=("brew",), scripts=brew_script(missing=True)))
    result = rnfmac("brew", "diff")
    assert result.code == 2
    assert "missing package from Brewfile" in result.out
    assert "0 ok, 0 warning, 1 drift, 0 error" in result.out


def test_json_suppresses_brew_output(sandbox, use_runner, rnfmac):
    use_runner(
        FakeRunner(
            tools=("brew",),
            scripts=brew_script(missing=True, extras='brew "unlisted"\n'),
        )
    )
    result = rnfmac("brew", "diff", "--json")
    assert result.code == 2
    payload = json.loads(result.out)
    codes = {f["code"] for f in payload["findings"]}
    assert codes == {"brew.brewfile-missing", "brew.brewfile-extra"}
    assert {f["details"]["group"] for f in payload["findings"]} == {"brew"}
    assert "missing package from Brewfile" not in result.out
    extra = next(f for f in payload["findings"] if f["code"] == "brew.brewfile-extra")
    assert extra["message"] == 'installed but not in Brewfile:\nbrew "unlisted"'


def test_extras_stop_at_the_brew_cleanup_preview(sandbox, use_runner, rnfmac):
    extras = 'brew "unlisted"\nWould `brew cleanup`:\nold-version\n'
    use_runner(FakeRunner(tools=("brew",), scripts=brew_script(extras=extras)))
    result = rnfmac("brew", "diff", "--json")
    assert result.code == 2
    message = json.loads(result.out)["findings"][0]["message"]
    assert "unlisted" in message
    assert "old-version" not in message


def test_a_missing_brew_is_drift(sandbox, rnfmac):
    # the default runner cannot start brew: check fails, cleanup lists nothing
    result = rnfmac("brew", "diff")
    assert result.code == 2
    assert "packages from the Brewfile are missing" in result.flat


# the awk file had no spec of its own; these pin the same rules


def test_dedupe_regroups_under_headers_and_drops_dependency_formulae():
    dump = 'tap "a/b"\nbrew "keep"\nbrew "dep"\ncask "app"\n'
    assert (
        dedupe_brewfile(dump, {"keep"})
        == '## taps\ntap "a/b"\n\n## formulae\nbrew "keep"\n\n## casks\ncask "app"\n'
    )


def test_dedupe_keeps_a_comment_with_its_line_and_drops_it_with_a_dropped_one():
    dump = '# about keep\nbrew "keep"\n# about dep\nbrew "dep"\nbrew "keep2"\n'
    assert (
        dedupe_brewfile(dump, {"keep", "keep2"})
        == '## formulae\n# about keep\nbrew "keep"\nbrew "keep2"\n'
    )


def test_dedupe_matches_the_awk_on_blank_lines_and_unknown_kinds():
    dump = 'brew "a"\n\nvscode "x"\n'
    # verified against the awk: a blank line is its own group, so two blank lines come out
    assert dedupe_brewfile(dump, {"a"}) == '## formulae\nbrew "a"\n\n\nvscode "x"\n'


@pytest.mark.parametrize("host", ["..", "../..", "../../etc", ""])
def test_brewfile_path_refuses_a_host_outside_hosts(tmp_path, host):
    layout = Layout(user_home=tmp_path, rnf_home=tmp_path / ".rn-forge")
    with pytest.raises(AppException):
        brewfile_path(layout, host)
