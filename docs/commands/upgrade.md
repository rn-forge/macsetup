# upgrade.sh

`rnfmac upgrade` — downloads the latest macsetup release and installs it.

## Overview

Script to download the latest macsetup release and install it
Version: 2.0
Author: Rohit Narayanan

## Index

* [sha256_of](#sha256_of)
* [read_dist_version](#read_dist_version)
* [atomic_install](#atomic_install)
* [acquire_install_lock](#acquire_install_lock)
* [execute](#execute)

### sha256_of

Print the sha256 of a file — sha256sum on Linux, shasum on macOS.

#### Arguments

* **$1** (string): Path to the file to hash.

#### Output on stdout

* The hex-encoded sha256 digest.

### read_dist_version

Validate and print the version in a VERSION file — guards against a
truncated download or corrupt file silently producing a bogus install path.

#### Arguments

* **$1** (string): Path to the VERSION file.

#### Exit codes

* **0**: VERSION matches `X.Y.Z` (with optional `-`/`+` suffix).
* **1**: VERSION is missing or malformed.

#### Output on stdout

* The validated version string.

### atomic_install

Copy a staged dist tree into place atomically: builds in a scratch
dir next to the destination first, then rm+mv swaps it into place — a failed
copy only ever corrupts the scratch dir, never leaves a partially-overwritten
install.

#### Arguments

* **$1** (string): Source dir (a staged dist tree).
* **$2** (string): Destination dist path.

### acquire_install_lock

Serialize concurrent upgrades via a mkdir-based lock — portable
across macOS/Linux, unlike flock. Released by a trap: this script always runs
standalone (never sourced into a caller's shell), so a trap here is safe.

#### Arguments

* **$1** (string): Lock directory path to create.

#### Exit codes

* **0**: Lock acquired (an EXIT trap releasing it is now set).
* **1**: Timed out after 30s waiting for the lock.

### execute

Run `rnfmac upgrade`: download and verify the latest release
tarball, install it as a new version dir (no-op if already current), flip
`current`, then exec the new dist's sync.sh to re-sync profile/brew/system.

#### Arguments

* **...** (string): Forwarded to the new dist's `commands/sync.sh` on completion.

