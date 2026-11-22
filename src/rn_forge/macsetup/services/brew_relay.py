"""`rnfmac brew relay`: apply, remove or regenerate the Homebrew Remote Relay patches.

Every apply resets the Homebrew repo to its clean base and re-applies the
packaged patches fresh; nothing is cherry-picked from a stored commit.
"""

from __future__ import annotations

from pathlib import Path

from rn_forge.commons.exceptions import AppException
from rn_forge.commons.runtime.console import console

from rn_forge.macsetup.domain.runner import Runner

__all__ = [
    "MANAGED_FILES",
    "RELAY_SUBJECT",
    "apply_relay",
    "checkout_root",
    "ensure_homebrew_repo",
    "ensure_relay_applied",
    "force_relay",
    "regen_patches",
    "reset_relay",
]

MANAGED_FILES = (
    "Library/Homebrew/download_strategy.rb",
    "Library/Homebrew/download_strategy/download_strategy_detector.rb",
    "Library/Homebrew/cmd/vendor-install.sh",
)
"""The Homebrew files the relay patches, relative to the prefix."""

STRATEGY = "Library/Homebrew/download_strategy/remote_relay_curl_download_strategy.rb"
RELAY_SUBJECT = "rn-forge: apply Homebrew remote relay"
"""The subject of the commit that marks the relay as applied."""


def _git(prefix: Path, *args: str) -> list[str]:
    return ["git", "-C", str(prefix), *args]


def _checked(runner: Runner, args: list[str]) -> None:
    """Run *args*; a failure stops the relay, as `set -e` did in the shell version."""
    result = runner.run(args)
    if result.returncode != 0:
        raise AppException("{} failed: {}", " ".join(args), result.stderr.strip())


def _is_relay_head(prefix: Path, runner: Runner) -> bool:
    result = runner.run(_git(prefix, "log", "-1", "--pretty=%s"))
    return result.returncode == 0 and result.stdout.strip() == RELAY_SUBJECT


def ensure_homebrew_repo(prefix: Path, runner: Runner) -> None:
    """Refuse to go on unless *prefix* exists and is itself the root of a git repo.

    Args:
        prefix: The Homebrew install.
        runner: Runs `git`.

    Raises:
        AppException: The prefix is missing, not a repository, or nested in one.
    """
    if not prefix.is_dir():
        raise AppException(
            "this system is not compatible with the Homebrew relay — {} not found "
            "(Apple Silicon Homebrew installs only)",
            prefix,
        )
    top = runner.run(_git(prefix, "rev-parse", "--show-toplevel"))
    if top.returncode != 0:
        raise AppException("{} is not a git repository", prefix)
    toplevel = top.stdout.strip()
    if Path(toplevel).resolve() != prefix.resolve():
        raise AppException(
            "{} is not the root of its git repository (root is {}) — refusing to "
            "operate on it",
            prefix,
            toplevel,
        )


def _reset_to_clean_base(prefix: Path, runner: Runner) -> None:
    """Drop the relay commit if present (else a hard reset) and delete the strategy file."""
    target = "HEAD^" if _is_relay_head(prefix, runner) else "HEAD"
    _checked(runner, _git(prefix, "reset", "--hard", target))
    (prefix / STRATEGY).unlink(missing_ok=True)


def apply_relay(prefix: Path, strategy: Path, patches: Path, runner: Runner) -> None:
    """Reset to the clean base, copy in the strategy, apply the patches and commit.

    Args:
        prefix: The Homebrew install.
        strategy: The relay download strategy source file.
        patches: The directory holding one `<basename>.patch` per managed file.
        runner: Runs `git`; `apply --3way` streams so conflicts reach the terminal.

    Raises:
        AppException: A patch did not apply; Homebrew is reset to its clean base.
    """
    _reset_to_clean_base(prefix, runner)
    destination = prefix / STRATEGY
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(strategy.read_bytes())
    failed = False
    for managed in MANAGED_FILES:
        patch = patches / f"{Path(managed).name}.patch"
        if runner.stream(_git(prefix, "apply", "--3way", str(patch))) != 0:
            failed = True
    if failed:
        console.warning("conflicts applying relay patches — see conflicted files above")
        _reset_to_clean_base(prefix, runner)
        raise AppException(
            "reset Homebrew back to its clean base; regenerate patches with "
            "'rnfmac brew relay --regen'"
        )
    _checked(runner, _git(prefix, "add", *MANAGED_FILES, STRATEGY))
    _checked(
        runner,
        _git(
            prefix,
            "-c",
            "user.name=rn-forge",
            "-c",
            "user.email=rn-forge@local",
            "commit",
            "-q",
            "-m",
            RELAY_SUBJECT,
        ),
    )
    console.success("homebrew remote_relay applied")


def ensure_relay_applied(
    prefix: Path, strategy: Path, patches: Path, runner: Runner
) -> None:
    """Apply the relay unless HEAD already is the relay commit."""
    if _is_relay_head(prefix, runner):
        console.success("homebrew remote_relay already applied")
        return
    console.info("Applying Homebrew relay patches ...")
    apply_relay(prefix, strategy, patches, runner)


def force_relay(prefix: Path, strategy: Path, patches: Path, runner: Runner) -> None:
    """Reset to the clean base, `brew update`, then apply the relay unconditionally."""
    console.info("Resetting and reapplying Homebrew relay patches ...")
    _reset_to_clean_base(prefix, runner)
    if runner.stream(["brew", "update"]) != 0:
        raise AppException("brew update failed")
    apply_relay(prefix, strategy, patches, runner)


def reset_relay(prefix: Path, runner: Runner) -> None:
    """Reset Homebrew to its clean upstream base."""
    _reset_to_clean_base(prefix, runner)
    console.success(
        "homebrew remote_relay removed — {} is on a clean upstream base", prefix
    )


def checkout_root(patches: Path, runner: Runner) -> Path:
    """Return the git work tree that holds the patch directory.

    Args:
        patches: The packaged patch directory.
        runner: Runs `git`.

    Raises:
        AppException: The patch directory is not inside a git work tree.
    """
    result = runner.run(["git", "-C", str(patches), "rev-parse", "--show-toplevel"])
    if result.returncode != 0 or not result.stdout.strip():
        raise AppException(
            "'--regen' requires a git checkout — run from the macsetup checkout"
        )
    return Path(result.stdout.strip())


def regen_patches(
    prefix: Path, patches: Path, runner: Runner, mirror: Path | None = None
) -> None:
    """Rewrite each patch from the hand-edited, clean-base worktree at *prefix*.

    Args:
        prefix: The Homebrew install, with hand edits uncommitted.
        patches: Where to write `<basename>.patch`.
        runner: Runs `git`.
        mirror: A second directory that receives the same bytes, if given.

    Raises:
        AppException: HEAD is the relay commit.
    """
    if _is_relay_head(prefix, runner):
        raise AppException(
            "{} HEAD is the relay commit — regen must run against a clean-base "
            "worktree with your hand edits uncommitted. Run 'rnfmac brew relay "
            "--reset', hand-edit, then --regen.",
            prefix,
        )
    for managed in MANAGED_FILES:
        name = f"{Path(managed).name}.patch"
        diff = runner.run(_git(prefix, "diff", "--no-color", "HEAD", "--", managed))
        for directory in (patches, mirror):
            if directory is not None:
                (directory / name).write_text(diff.stdout)
        if not diff.stdout:
            console.warning(
                "no diff found for {} — is it hand-edited in {}?", managed, prefix
            )
        console.success("regenerated {}", name)
