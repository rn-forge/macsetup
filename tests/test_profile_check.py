"""Ports of tests/commands/profile/check_spec.sh."""

import json

from rn_forge.macsetup.domain.layout import Layout


def render(sandbox) -> bytes:
    """The rendered profile as `profile sync` writes it, spelled out independently of the code under test."""
    config = sandbox.config
    return (
        "#################### macsetup profile — rendered by profile/sync.sh, DO NOT EDIT\n".encode()
        + (config / "shared" / "profile.zsh").read_bytes()
        + b"\n#################### aliases\n"
        + (config / "shared" / "aliases.zsh").read_bytes()
        + b"\n#################### host overrides: testhost\n"
        + (config / "hosts" / "testhost" / "profile.zsh").read_bytes()
    )


def synced(sandbox) -> None:
    """Leave the sandbox as `rnfmac profile sync` would."""
    layout = Layout(sandbox.home, sandbox.rnf_home)
    layout.rendered_profile.write_bytes(render(sandbox))
    block = f"\n{layout.marker}\n{layout.source_line}\n"
    for name in (".zprofile", ".zshrc"):
        with (sandbox.home / name).open("a") as handle:
            handle.write(block)


def test_hides_healthy_records_by_default(sandbox, rnfmac):
    synced(sandbox)
    result = rnfmac("profile", "check")
    assert result.code == 0
    for text in (
        "rendered profile.zsh is up to date",
        ".zprofile is patched",
        ".zshrc is patched",
    ):
        assert text not in result.out
    assert "3 ok, 0 warning, 0 drift, 0 error" in result.out


def test_all_includes_healthy_records(sandbox, rnfmac):
    synced(sandbox)
    result = rnfmac("profile", "check", "--all")
    assert result.code == 0
    for text in (
        "rendered profile.zsh is up to date",
        ".zprofile is patched",
        ".zshrc is patched",
    ):
        assert text in result.out


def test_warns_but_succeeds_without_a_profile_for_the_host(sandbox, rnfmac):
    (sandbox.config / "hosts" / "testhost" / "profile.zsh").unlink()
    result = rnfmac("profile", "check")
    assert result.code == 0
    assert "no profile for host 'testhost'" in result.flat
    assert "0 ok, 1 warning, 0 drift, 0 error" in result.out


def test_flags_a_stale_rendered_profile(sandbox, rnfmac):
    synced(sandbox)
    with (sandbox.config / "shared" / "profile.zsh").open("a") as handle:
        handle.write("\n# drift\n")
    result = rnfmac("profile", "check")
    assert result.code == 2
    assert "rendered profile.zsh is stale" in result.flat


def test_flags_a_missing_rendered_profile(sandbox, rnfmac):
    result = rnfmac("profile", "check")
    assert result.code == 2
    assert "no rendered profile at" in result.flat


def test_flags_missing_rc_file_patches(sandbox, rnfmac):
    synced(sandbox)
    (sandbox.home / ".zprofile").write_text("")
    (sandbox.home / ".zshrc").write_text("")
    result = rnfmac("profile", "check")
    assert result.code == 2
    assert ".zprofile is missing the macsetup marker" in result.flat
    assert ".zshrc is missing the macsetup marker" in result.flat


def test_emits_clean_json_with_the_profile_group(sandbox, rnfmac):
    synced(sandbox)
    result = rnfmac("profile", "check", "--json")
    assert result.code == 0
    payload = json.loads(result.out)
    assert {f["details"]["group"] for f in payload["findings"]} == {"profile"}
    assert {f["details"]["status"] for f in payload["findings"]} == {"ok"}
    assert "[info]" not in result.out


def test_help_describes_the_command(rnfmac):
    result = rnfmac("profile", "check", "--help")
    assert result.code == 0
    assert "profile check" in result.out
    assert "--all" in result.out


def test_a_missing_shared_source_is_an_error(sandbox, rnfmac):
    synced(sandbox)
    (sandbox.config / "shared" / "aliases.zsh").unlink()
    result = rnfmac("profile", "check")
    assert result.code == 1
    assert "cannot render the profile" in result.flat


def test_a_source_line_alone_does_not_count_as_patched(sandbox, rnfmac):
    synced(sandbox)
    layout = Layout(sandbox.home, sandbox.rnf_home)
    (sandbox.home / ".zshrc").write_text(layout.source_line + "\n")
    result = rnfmac("profile", "check")
    assert result.code == 2
    assert ".zshrc is missing" in result.flat
