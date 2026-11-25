"""Ports of tests/commands/profile/sync_spec.sh."""

import itertools

import pytest

from rn_forge.macsetup import assets
from rn_forge.macsetup.domain.layout import Layout
from rn_forge.macsetup.services import profile_sync
from rn_forge.macsetup.services.profile_check import render_profile

THEME = "rohitnarayanan.zsh-theme"


@pytest.fixture(autouse=True)
def ticking_clock(monkeypatch):
    """A backup timestamp that is unique per call, so same-second runs cannot collide."""
    counter = itertools.count()
    monkeypatch.setattr(
        profile_sync, "_timestamp", lambda: f"20260101{next(counter):06d}"
    )


def layout_of(sandbox) -> Layout:
    return Layout(sandbox.home, sandbox.rnf_home)


def theme_path(sandbox):
    return sandbox.home / ".oh-my-zsh" / "custom" / "themes" / THEME


def snapshot(sandbox) -> dict:
    return {str(p): p.read_bytes() for p in sandbox.root.rglob("*") if p.is_file()}


def backups(sandbox, name: str) -> list:
    folder = sandbox.rnf_home / "backup" / "macsetup"
    return sorted(folder.glob(f"{name}_*")) if folder.is_dir() else []


def test_renders_shared_and_host_profile_and_copies_the_brewfile(sandbox, rnfmac):
    result = rnfmac("profile", "sync")
    assert result.code == 0
    assert "Profile synced successfully !" in result.flat
    layout = layout_of(sandbox)
    assert layout.rendered_profile.read_bytes() == render_profile(layout, "testhost")
    assert (layout.product_home / "Brewfile").read_bytes() == (
        sandbox.config / "hosts" / "testhost" / "Brewfile"
    ).read_bytes()


def test_patches_zprofile_and_zshrc(sandbox, rnfmac):
    assert rnfmac("profile", "sync").code == 0
    layout = layout_of(sandbox)
    for name in (".zprofile", ".zshrc"):
        text = (sandbox.home / name).read_text()
        assert layout.marker in text
        assert layout.source_line in text
    assert (sandbox.home / ".zprofile").read_text() == (
        f"{layout.marker}\n{layout.source_line}\n"
    )
    assert (sandbox.home / ".zshrc").read_text() == (
        f"{layout.marker}\n{layout.source_line}\n\nsource $ZSH/oh-my-zsh.sh\n"
    )


def test_second_run_changes_nothing(sandbox, rnfmac):
    assert rnfmac("profile", "sync").code == 0
    layout = layout_of(sandbox)
    written = [
        layout.rendered_profile,
        layout.product_home / "Brewfile",
        sandbox.home / ".zprofile",
        sandbox.home / ".zshrc",
        theme_path(sandbox),
        sandbox.home / "Library" / "KeyBindings" / "DefaultKeyBinding.dict",
    ]
    before = {p: p.read_bytes() for p in written}
    assert rnfmac("profile", "sync").code == 0
    assert {p: p.read_bytes() for p in written} == before
    for name in (".zprofile", ".zshrc"):
        assert (sandbox.home / name).read_text().count(layout.marker) == 1


def test_completes_an_old_zprofile_block_missing_the_source_line(sandbox, rnfmac):
    layout = layout_of(sandbox)
    stale = "export SOME_OLD_MACSETUP_VAR=1"
    (sandbox.home / ".zprofile").write_text(f"{layout.marker}\n{stale}\n")
    assert rnfmac("profile", "sync").code == 0
    text = (sandbox.home / ".zprofile").read_text()
    assert text.count(layout.marker) == 1
    assert text.count(stale) == 1
    assert text.endswith(f"{layout.source_line}\n")


def test_a_missing_host_profile_is_an_error(sandbox, rnfmac):
    (sandbox.config / "hosts" / "testhost" / "profile.zsh").unlink()
    result = rnfmac("profile", "sync")
    assert result.code == 1
    assert "no profile for host 'testhost'" in result.flat
    layout = layout_of(sandbox)
    assert not layout.rendered_profile.exists()
    assert not (layout.product_home / "Brewfile").exists()
    assert not (sandbox.home / ".zprofile").exists()


def test_a_missing_brewfile_is_an_error_after_rendering(sandbox, rnfmac):
    (sandbox.config / "hosts" / "testhost" / "Brewfile").unlink()
    result = rnfmac("profile", "sync")
    assert result.code == 1
    assert "no Brewfile for host 'testhost'" in result.flat
    layout = layout_of(sandbox)
    assert layout.rendered_profile.is_file()
    assert not (layout.product_home / "Brewfile").exists()


def test_sets_zsh_theme_from_the_rendered_profile(sandbox, rnfmac):
    with (sandbox.config / "hosts" / "testhost" / "profile.zsh").open("a") as handle:
        handle.write('export ZSH_THEME="x"\n')
    (sandbox.home / ".zshrc").write_text(
        'ZSH_THEME="robbyrussell"\nsource $ZSH/oh-my-zsh.sh\n'
    )
    assert rnfmac("profile", "sync").code == 0
    lines = (sandbox.home / ".zshrc").read_text().splitlines()
    assert 'ZSH_THEME="x"' in lines
    assert 'ZSH_THEME="robbyrussell"' not in lines


def test_installs_theme_and_keybindings_from_assets(sandbox, rnfmac):
    assert rnfmac("profile", "sync").code == 0
    assert theme_path(sandbox).read_bytes() == assets.read_asset(
        "profiles", "shared", THEME
    )
    keys = sandbox.home / "Library" / "KeyBindings" / "DefaultKeyBinding.dict"
    assert keys.read_bytes() == assets.read_asset(
        "profiles", "shared", "DefaultKeyBinding.dict"
    )


def test_replaces_a_theme_symlink_without_writing_through_it(sandbox, rnfmac):
    other = sandbox.root / "shell-install-theme"
    other.write_text("original")
    theme_path(sandbox).symlink_to(other)
    assert rnfmac("profile", "sync").code == 0
    assert other.read_text() == "original"
    assert not theme_path(sandbox).is_symlink()
    assert theme_path(sandbox).is_file()


def test_backs_up_changed_files_once(sandbox, rnfmac):
    assert rnfmac("profile", "sync").code == 0
    assert rnfmac("profile", "sync").code == 0
    first = snapshot(sandbox)
    assert backups(sandbox, ".zshrc")
    count = len(backups(sandbox, ".zshrc"))
    assert rnfmac("profile", "sync").code == 0
    assert snapshot(sandbox) == first
    with (sandbox.home / ".zshrc").open("a") as handle:
        handle.write("# changed\n")
    assert rnfmac("profile", "sync").code == 0
    assert len(backups(sandbox, ".zshrc")) == count + 1
