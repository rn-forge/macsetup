"""The structured health report: records, their worst status and their exit code.

A record's status is `error`, `drift`, `warning` or `ok`. `rn-forge-commons`
findings have no drift level, so `to_finding` maps drift onto a warning and keeps
the macsetup status in `details`; the exit code comes from the status, not the
severity.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from enum import StrEnum

from rn_forge.commons.findings import Finding, Severity

__all__ = ["CATEGORY_ORDER", "Record", "Report", "Status"]

CATEGORY_ORDER = ("toolchain", "runtime", "profile", "packages")
"""The order categories are rendered in."""


class Status(StrEnum):
    """A record's status, worst first."""

    ERROR = "error"
    DRIFT = "drift"
    WARNING = "warning"
    OK = "ok"


_SEVERITY = {
    Status.ERROR: Severity.ERROR,
    Status.DRIFT: Severity.WARNING,
    Status.WARNING: Severity.WARNING,
    Status.OK: Severity.INFO,
}


@dataclass(frozen=True, slots=True)
class Record:
    """One check result."""

    status: Status
    group: str
    category: str
    check: str
    message: str

    def to_finding(self) -> Finding:
        """This record as a finding: code `<group>.<check>`, status kept in details."""
        return Finding(
            f"{self.group}.{self.check}",
            _SEVERITY[self.status],
            self.message,
            details={
                "status": self.status.value,
                "group": self.group,
                "category": self.category,
            },
        )


@dataclass(slots=True)
class Report:
    """The records of one run, collected in order."""

    group: str
    records: list[Record] = field(default_factory=list[Record])

    def add(self, status: Status, category: str, check: str, message: str) -> None:
        """Append a record."""
        self.records.append(Record(status, self.group, category, check, message))

    def extend(self, other: Report) -> None:
        """Append another report's records, keeping their own groups."""
        self.records.extend(other.records)

    def count(self, status: Status) -> int:
        """How many records have *status*."""
        return sum(1 for record in self.records if record.status is status)

    @property
    def worst(self) -> Status:
        """The worst status present, `ok` for an empty report."""
        for status in (Status.ERROR, Status.DRIFT, Status.WARNING):
            if self.count(status):
                return status
        return Status.OK

    @property
    def exit_code(self) -> int:
        """1 for an error, 2 for drift, otherwise 0."""
        return {Status.ERROR: 1, Status.DRIFT: 2}.get(self.worst, 0)

    def findings(self) -> list[Finding]:
        """Every record as a finding."""
        return [record.to_finding() for record in self.records]
