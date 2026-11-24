import pytest

from rn_forge.macsetup.assets import asset, asset_names, read_asset

SHARED_PROFILE = ["DefaultKeyBinding.dict", "rohitnarayanan.zsh-theme"]
RELAY_PATCHES = [
    "download_strategy.rb.patch",
    "download_strategy_detector.rb.patch",
    "vendor-install.sh.patch",
]
STRATEGY = "remote_relay_curl_download_strategy.rb"


def test_the_shared_profile_assets_are_shipped():
    assert asset_names("profiles", "shared") == SHARED_PROFILE


def test_the_relay_assets_are_shipped():
    assert asset_names("homebrew", "patches") == RELAY_PATCHES
    assert asset_names("homebrew", "download_strategy") == [STRATEGY]


@pytest.mark.parametrize(
    "parts",
    [
        *[("profiles", "shared", name) for name in SHARED_PROFILE],
        *[("homebrew", "patches", name) for name in RELAY_PATCHES],
        ("homebrew", "download_strategy", STRATEGY),
    ],
)
def test_each_asset_is_readable_and_not_empty(parts):
    assert asset(*parts).is_file()
    assert read_asset(*parts)


def test_a_missing_asset_raises():
    with pytest.raises(FileNotFoundError):
        read_asset("profiles", "shared", "nope")
