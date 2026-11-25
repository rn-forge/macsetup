"""`rnfmac config status`: the config checkout's identity, remote state and local changes."""

from __future__ import annotations

from rn_forge.commons.exceptions import AppException

from rn_forge.macsetup.domain.layout import CONFIG_BRANCH, Layout
from rn_forge.macsetup.domain.runner import Result, Runner

__all__ = ["ConfigStatus", "config_status", "require_config_checkout"]


def require_config_checkout(layout: Layout, runner: Runner) -> None:
    """Verify the config checkout exists and is on `main`.

    Raises:
        AppException: The checkout is missing or invalid, or on another branch.
    """
    config = layout.config_home
    if not runner.run(
        ["git", "-C", str(config), "rev-parse", "--is-inside-work-tree"]
    ).ok:
        raise AppException("macsetup config checkout is invalid at {}", config)
    branch = runner.run(["git", "-C", str(config), "branch", "--show-current"])
    name = branch.stdout.strip()
    if name != CONFIG_BRANCH:
        raise AppException(
            "macsetup config must be on '{}' (currently '{}')",
            CONFIG_BRANCH,
            name or "detached",
        )


class ConfigStatus:
    """Builds the report as a list of `(kind, text)` lines, where kind is `text`, `success` or `notice`."""

    def __init__(self, layout: Layout, runner: Runner) -> None:
        """Bind the checkout to inspect."""
        self._config = layout.config_home
        self._runner = runner
        self.lines: list[tuple[str, str]] = []

    def _git(self, *args: str) -> Result:
        return self._runner.run(["git", "-C", str(self._config), "--no-pager", *args])

    def _text(self, text: str) -> None:
        self.lines.append(("text", text))

    def _block(self, text: str) -> None:
        """Add command output, or nothing when it printed nothing."""
        if text.strip():
            self._text(text.rstrip("\n"))

    def _checked(self, *args: str) -> str:
        result = self._git(*args)
        if not result.ok:
            raise AppException(
                "git {} failed in {}: {}", args[0], self._config, result.stderr.strip()
            )
        return result.stdout

    def identity(self) -> None:
        """The checkout location, branch and current revision."""
        self._text(f"config:   {self._config}")
        branch = self._checked("branch", "--show-current").strip()
        self._text(f"branch:   {branch}")
        revision = self._checked("log", "-1", "--format=%h %s (%ar)").strip()
        self._text(f"revision: {revision}")

    def remote(self) -> None:
        """Fetch origin and compare. A failed fetch is reported, not fatal."""
        branch = CONFIG_BRANCH
        if not self._git("fetch", "--quiet", "origin", branch).ok:
            self._text(
                "remote:   unreachable — comparison below is against the last fetch"
            )
            return
        behind = int(
            self._checked("rev-list", "--count", f"HEAD..origin/{branch}").strip()
        )
        if behind == 0:
            self._text(f"remote:   up to date with origin/{branch}")
            return
        self._text(
            f"remote:   {behind} commit(s) behind origin/{branch} — run 'rnfmac config pull'"
        )
        self._text("")
        self._text("incoming:")
        self._block(
            self._checked("log", "--oneline", "--no-decorate", f"HEAD..origin/{branch}")
        )

    def local_changes(self) -> None:
        """The full diff of unpublished work, including untracked files."""
        if not self._checked("status", "--porcelain").strip():
            self._text("")
            self.lines.append(("success", "no local changes"))
            return
        self._text("")
        self._text("local changes:")
        self._block(self._checked("status", "--short"))
        self._text("")
        self._block(self._checked("diff", "--stat", "HEAD"))
        self._text("")
        self._block(self._checked("diff", "HEAD"))
        for name in self._checked(
            "ls-files", "--others", "--exclude-standard"
        ).splitlines():
            if name:
                # `git diff --no-index` exits 1 when the files differ, which is the point
                shown = self._git("diff", "--no-index", "--", "/dev/null", name)
                self._block(shown.stdout)
        self._text("")
        self.lines.append(
            ("notice", "publish with 'rnfmac config push --message <message>'")
        )


def config_status(layout: Layout, runner: Runner) -> list[tuple[str, str]]:
    """Report the config checkout's branch, revision, remote comparison and local diff.

    Raises:
        AppException: The checkout is missing, invalid or on another branch.
    """
    require_config_checkout(layout, runner)
    status = ConfigStatus(layout, runner)
    status.identity()
    status.remote()
    status.local_changes()
    return status.lines
