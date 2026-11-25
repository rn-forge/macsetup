"""`config pull`, `config push` and `config reset`: move the config checkout and origin together."""

from __future__ import annotations

from collections.abc import Callable, Mapping

from rn_forge.commons.exceptions import AppException

from rn_forge.macsetup.domain.layout import CONFIG_BRANCH, Layout
from rn_forge.macsetup.domain.runner import Result, Runner
from rn_forge.macsetup.services.config_status import require_config_checkout

__all__ = [
    "Notify",
    "config_pull",
    "config_push",
    "config_repo_url",
    "config_reset",
    "ensure_config_checkout",
    "update_config_checkout",
]

Notify = Callable[[str, str], None]
"""Receives `(kind, text)`, where kind is `info`, `success`, `notice` or `text`."""

_REMOTE = f"origin/{CONFIG_BRANCH}"


def config_repo_url(env: Mapping[str, str]) -> str:
    """The URL the config checkout is cloned from, as `config/lib.sh` derives it."""
    return env.get("RNFMAC_CONFIG_REPO_URL") or (
        f"https://github.com/{env.get('RNF_GITHUB_ORG') or 'rn-forge'}/macsetup-config.git"
    )


def _git(layout: Layout, runner: Runner, *args: str) -> Result:
    return runner.run(["git", "-C", str(layout.config_home), "--no-pager", *args])


def _checked(layout: Layout, runner: Runner, *args: str) -> str:
    result = _git(layout, runner, *args)
    if not result.ok:
        raise AppException(
            "git {} failed in {}: {}",
            args[0],
            layout.config_home,
            result.stderr.strip(),
        )
    return result.stdout


def _short_head(layout: Layout, runner: Runner) -> str:
    return _checked(layout, runner, "rev-parse", "--short", "HEAD").strip()


def _dirty(layout: Layout, runner: Runner) -> bool:
    return bool(_checked(layout, runner, "status", "--porcelain").strip())


def ensure_config_checkout(
    layout: Layout, runner: Runner, url: str, notify: Notify
) -> None:
    """Clone the config checkout when it is absent, then validate it.

    Args:
        layout: Where the checkout lives.
        runner: Runs `git`.
        url: The repository to clone from.
        notify: Receives progress lines.

    Raises:
        AppException: The clone failed, or the checkout is invalid.
    """
    if not layout.config_home.exists():
        notify("info", f"cloning macsetup config from {url} ...")
        result = runner.run(
            [
                "git",
                "clone",
                "--quiet",
                "--branch",
                CONFIG_BRANCH,
                "--single-branch",
                url,
                str(layout.config_home),
            ]
        )
        if not result.ok:
            raise AppException(
                "could not clone macsetup config from {}: {}",
                url,
                result.stderr.strip(),
            )
    require_config_checkout(layout, runner)


def update_config_checkout(layout: Layout, runner: Runner, notify: Notify) -> None:
    """Fast-forward the checkout onto `origin/main`, carrying uncommitted changes on a stash.

    Only genuine divergence (local commits absent from the remote) is refused.

    Args:
        layout: Where the checkout lives.
        runner: Runs `git`.
        notify: Receives progress lines.

    Raises:
        AppException: The checkout diverged, could not fast-forward, or the
            stash conflicted with the update.
    """
    config = layout.config_home
    _checked(layout, runner, "fetch", "--quiet", "origin", CONFIG_BRANCH)
    local = _checked(layout, runner, "rev-parse", "HEAD").strip()
    remote = _checked(layout, runner, "rev-parse", _REMOTE).strip()
    if local == remote:
        return
    if not _git(layout, runner, "merge-base", "--is-ancestor", "HEAD", _REMOTE).ok:
        raise AppException(
            "macsetup config has local commits that are not on {} — reconcile {} by hand",
            _REMOTE,
            config,
        )
    stashed = _dirty(layout, runner)
    if stashed:
        notify("info", "holding local config changes aside while updating ...")
        _checked(
            layout,
            runner,
            "stash",
            "push",
            "--quiet",
            "--include-untracked",
            "--message",
            "rnfmac config update",
        )
    if not _git(layout, runner, "merge", "--quiet", "--ff-only", _REMOTE).ok:
        if stashed:
            _git(layout, runner, "stash", "pop", "--quiet")
        raise AppException("could not fast-forward macsetup config to {}", _REMOTE)
    notify("info", f"updated macsetup config to {_short_head(layout, runner)}")
    if stashed and not _git(layout, runner, "stash", "pop", "--quiet").ok:
        raise AppException(
            "local config changes conflict with {} — resolve the conflicts in {}, "
            "then run 'rnfmac config push --message <message>'",
            _REMOTE,
            config,
        )


def config_pull(layout: Layout, runner: Runner, url: str, notify: Notify) -> None:
    """Clone or fast-forward the config checkout, keeping local changes.

    Raises:
        AppException: The checkout could not be created or updated.
    """
    ensure_config_checkout(layout, runner, url, notify)
    notify("info", "Updating macsetup config ...")
    update_config_checkout(layout, runner, notify)
    notify("success", f"macsetup config is current ({_short_head(layout, runner)})")
    if _dirty(layout, runner):
        notify(
            "notice",
            "local config changes are still unpublished — see 'rnfmac config status'",
        )


def config_push(layout: Layout, runner: Runner, message: str, notify: Notify) -> None:
    """Fast-forward onto `origin/main`, then commit every local change and publish it.

    Args:
        layout: Where the checkout lives.
        runner: Runs `git`.
        message: The commit message.
        notify: Receives progress lines.

    Raises:
        AppException: There is nothing to publish, or git failed.
    """
    require_config_checkout(layout, runner)
    if not _dirty(layout, runner):
        raise AppException("macsetup config has no changes to publish")
    update_config_checkout(layout, runner, notify)
    _checked(layout, runner, "add", "-A")
    _checked(layout, runner, "commit", "-m", message)
    _checked(layout, runner, "push", "--quiet", "origin", CONFIG_BRANCH)
    notify("success", f"macsetup config published ({_short_head(layout, runner)})")


def config_reset(layout: Layout, runner: Runner, force: bool, notify: Notify) -> None:
    """Hard-reset the checkout to `origin/main`, discarding local changes when *force*.

    Args:
        layout: Where the checkout lives.
        runner: Runs `git`.
        force: Allow discarding local changes.
        notify: Receives progress lines.

    Raises:
        AppException: Local changes exist and *force* is not set, or git failed.
    """
    require_config_checkout(layout, runner)
    _checked(layout, runner, "fetch", "--quiet", "origin", CONFIG_BRANCH)
    if not _dirty(layout, runner):
        _checked(layout, runner, "reset", "--quiet", "--hard", _REMOTE)
        notify(
            "success",
            f"macsetup config is already clean ({_short_head(layout, runner)})",
        )
        return
    if not force:
        notify("text", _checked(layout, runner, "status", "--short").rstrip("\n"))
        raise AppException(
            "macsetup config has local changes that would be discarded — rerun with --force"
        )
    _checked(layout, runner, "reset", "--quiet", "--hard", _REMOTE)
    _checked(layout, runner, "clean", "--quiet", "-fd")
    notify(
        "success",
        f"macsetup config reset to {_REMOTE} ({_short_head(layout, runner)})",
    )
