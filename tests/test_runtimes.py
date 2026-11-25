"""Version-list merging and Temurin identifier resolution."""

from __future__ import annotations

from rn_forge.macsetup.domain.runtimes import merge_versions, resolve_temurin

LISTING = """\
 Vendor        | Use | Version      | Dist    | Status     | Identifier
--------------------------------------------------------------------------
 Temurin       |     | 211.0.1      | tem     |            | 211.0.1-tem
               |     | 21.0.5       | tem     |            | 21.0.5-tem
               |     | 17.0.13      | tem     |            | 17.0.13-tem
 Zulu          |     | 21.0.5       | zulu    |            | 21.0.5-zulu
 Zulu          |     | 11.0.25      | zulu    |            | 11.0.25-zulu
"""


def test_merge_strips_comments_blanks_and_duplicates_in_order() -> None:
    assert merge_versions("21 # lts\n\n17\n", "17\n11\n") == ["21", "17", "11"]


def test_merge_with_no_files_is_empty() -> None:
    assert merge_versions(None, None) == []


def test_merge_host_only() -> None:
    assert merge_versions(None, "  3.12 \n# note\n3.13\n") == ["3.12", "3.13"]


def test_resolve_takes_an_exact_tem_identifier_as_is() -> None:
    assert resolve_temurin("21.0.5-tem", "") == "21.0.5-tem"


def test_resolve_matches_the_major_version_on_the_identifier_column() -> None:
    assert resolve_temurin("21", LISTING) == "21.0.5-tem"
    assert resolve_temurin("17", LISTING) == "17.0.13-tem"


def test_resolve_returns_none_without_a_match() -> None:
    assert resolve_temurin("11", LISTING) is None
    assert resolve_temurin("8", LISTING) is None
