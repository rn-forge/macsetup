# sync.sh

`rnfmac system sync` — installs pinned runtimes.

## Overview

Installs the runtimes declared in macsetup-config: python via uv, node via
nvm, java via SDKMAN. Each runtime's version list is shared/<runtime>-versions
merged with the optional hosts/<host>/<runtime>-versions override in the config
checkout (one version per line, `#` comments) — the first entry across the
merged list is installed as that runtime's default. A version that can't be
resolved or installed is logged as an error and skipped rather than aborting
the whole sync; the script exits non-zero if any version, across any runtime,
failed.
Version: 2.0
Author: Rohit Narayanan

## Index

* [read_runtime_versions](#read_runtime_versions)
* [sync_python](#sync_python)
* [sync_node](#sync_node)
* [resolve_temurin_identifier](#resolve_temurin_identifier)
* [sync_java](#sync_java)
* [sync_runtimes](#sync_runtimes)

### read_runtime_versions

Read and merge a runtime's version list: shared/<runtime>-versions
(required — at least one of shared or host must exist) plus the optional
hosts/<host>/<runtime>-versions override, comments/blank lines stripped,
deduped, order preserved (shared first, so shared entries win the "first =
default" position unless a host file lists its own first).

#### Arguments

* **$1** (string): Runtime name (`java`, `python`, or `node`).

#### Exit codes

* **0**: At least one version spec was found.
* **1**: Neither the shared nor the host file exists (or both are empty).

#### Output on stdout

* One version spec per line.

### sync_python

Install every configured python version via uv; the first
successfully installed version becomes the default.

_Function has no arguments._

#### Exit codes

* **0**: All configured versions installed.
* **1**: No version list was configured, or at least one version failed.

### sync_node

Install every configured node version via nvm; the first
successfully installed version becomes the default alias. A bare `lts` spec
resolves via `nvm install --lts`; anything else (an exact version, or an
`lts/<codename>`) is passed to `nvm install` directly.

_Function has no arguments._

#### Exit codes

* **0**: All configured versions installed.
* **1**: No version list was configured, or at least one version failed.

### resolve_temurin_identifier

Resolve a java version spec to a concrete Temurin identifier
against `sdk list java`'s output. A spec already ending `-tem` is trusted
as-is (an exact identifier); otherwise it's matched as a major-version prefix
against the Identifier column — always the last `|`-delimited field, and the
one column reliably tagged `-tem` for Temurin regardless of how the Vendor
column is spelled. Match on Identifier, not Vendor: Vendor's spelling isn't
consistent enough to filter on.

#### Arguments

* **$1** (string): Version spec — a major version (`21`) or an exact identifier.
* **$2** (string): The `sdk list java` output to search.

#### Output on stdout

* The resolved identifier, or nothing if no match was found.

### sync_java

Install every configured java version via SDKMAN; the first
successfully installed version becomes the SDKMAN default.

_Function has no arguments._

#### Exit codes

* **0**: All configured versions resolved and installed.
* **1**: No version list was configured, a version had no matching Temurin

### sync_runtimes

Run `rnfmac system sync`: install every configured python, node,
and java version. Each runtime is attempted even if an earlier one failed, so
one bad version spec never blocks the others.

_Function has no arguments._

#### Exit codes

* **0**: Every runtime synced cleanly.
* **1**: At least one runtime had a failed or unconfigured version.

