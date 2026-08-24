# upgrade.sh

`rnfmac upgrade` — installs the latest release and updates configuration.

## Overview

Downloads and installs the latest macsetup release, then updates the persistent
macsetup-config checkout without applying profile, brew, or system sync.
`--archive <path>` installs a release tarball already on disk instead of
downloading one — the offline/air-gapped route, and the way to move to a
specific build rather than whatever "latest" currently points at.
Version: 3.0
Author: Rohit Narayanan

## Index

* [usage](#usage)
* [parse_args](#parse_args)
* [sha256_of](#sha256_of)
* [verify_checksum](#verify_checksum)
* [read_dist_version](#read_dist_version)
* [atomic_install](#atomic_install)
* [acquire_install_lock](#acquire_install_lock)
* [fetch_release_tarball](#fetch_release_tarball)
* [stage_local_archive](#stage_local_archive)
* [execute](#execute)

### usage

Print `rnfmac upgrade` usage.

_Function has no arguments._

#### Output on stdout

* The usage text.

### parse_args

Parse CLI args, setting `ARCHIVE` and handling `-h`/`--help`.

#### Arguments

* **...** (string): Command arguments.

#### Variables set

* **ARCHIVE** (Path): to a release tarball to install instead of downloading one.

#### Exit codes

* **1**: Unrecognized or incomplete arguments.

### sha256_of

Print the sha256 of a file — sha256sum on Linux, shasum on macOS.

#### Arguments

* **$1** (string): Path to the file to hash.

#### Output on stdout

* The hex-encoded sha256 digest.

### verify_checksum

Compare a file against a sha256 sidecar.

#### Arguments

* **$1** (string): Path to the file to verify.
* **$2** (string): Path to the sidecar holding the expected digest.

#### Exit codes

* **0**: The digests match.
* **1**: The digests differ.

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

### fetch_release_tarball

Download the latest release tarball into `$1` and verify it against
its published sidecar.

#### Arguments

* **$1** (string): Destination path for the downloaded tarball.

#### Exit codes

* **1**: The download failed or the checksum did not match.

### stage_local_archive

Stage the `--archive` tarball into `$1`, verifying it against a
sibling `.sha256` sidecar when one exists.

#### Arguments

* **$1** (string): Destination path for the staged tarball.

#### Exit codes

* **1**: The archive is missing, or its checksum did not match.

### execute

Run `rnfmac upgrade`: stage the release tarball (downloaded, or the
`--archive` one), install it as a new version dir (no-op if already current),
flip `current`, and update macsetup-config without applying it.

_Function has no arguments._

