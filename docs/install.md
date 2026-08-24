# install.sh

Standalone macsetup installer, published as a release asset.

## Overview

Standalone macsetup installer — published as a release asset. Two ways to run it:
Streaming (fresh machine, no local checkout) — safe to source, downloads the
latest release:
. <(curl -fsSL https://github.com/rn-forge/macsetup/releases/latest/download/install.sh)
In-path (an unpacked release dist, or this repo's src/, sits next to this file)
— installs straight from that tree, no network round-trip for macsetup itself
(shkit below is still fetched fresh either way):
. src/install.sh
Archive (a release tarball already on disk) — unpacks and installs it, no
download; takes precedence over in-path detection:
. ./install.sh --archive ~/Downloads/macsetup.tar.gz
shkit is still fetched via curl even in in-path mode; if that curl is
blocked (e.g. a corporate proxy), set RNF_SHKIT_INSTALL_BUNDLE to the path of a
shkit release tarball fetched out-of-band — it's extracted and its
install.sh run locally instead of curling:
RNF_SHKIT_INSTALL_BUNDLE=./shkit.tar.gz . ./install.sh
Installs into ~/.rn-forge/macsetup/<version>/, clones macsetup-config into the
persistent product home, and links rnfmac. It does not touch .zprofile/.zshrc or
run bootstrap/sync; those stay with `rnfmac system init` / `rnfmac sync`.
Sourced contract: no `set -e`, no `exit` — a failure must never kill the caller's shell.
Version: 3.0
Author: Rohit Narayanan

## Index

* [_rnf_sha256_of](#_rnf_sha256_of)
* [_rnf_verify_checksum](#_rnf_verify_checksum)
* [_rnf_read_dist_version](#_rnf_read_dist_version)
* [_rnf_acquire_install_lock](#_rnf_acquire_install_lock)
* [_rnf_atomic_install](#_rnf_atomic_install)
* [_rnf_install_config_checkout](#_rnf_install_config_checkout)
* [_rnf_parse_install_args](#_rnf_parse_install_args)
* [rnfmac_install](#rnfmac_install)

### _rnf_sha256_of

Print the sha256 of a file — sha256sum on Linux, shasum on macOS.

#### Arguments

* **$1** (string): Path to the file to hash.

#### Output on stdout

* The hex-encoded sha256 digest.

### _rnf_verify_checksum

Compare a file against a sha256 sidecar.

#### Arguments

* **$1** (string): Path to the file to verify.
* **$2** (string): Path to the sidecar holding the expected digest.

#### Exit codes

* **0**: The digests match.
* **1**: The digests differ.

### _rnf_read_dist_version

Validate and print the version in a VERSION file — guards against a
truncated download or corrupt file silently producing a bogus install path.

#### Arguments

* **$1** (string): Path to the VERSION file.

#### Exit codes

* **0**: VERSION matches `X.Y.Z` (with optional `-`/`+` suffix).
* **1**: VERSION is missing or malformed.

#### Output on stdout

* The validated version string.

### _rnf_acquire_install_lock

Serialize concurrent installs (e.g. two terminals bootstrapping at
once) via a mkdir-based lock — portable across macOS/Linux, unlike flock. Fails
after a bounded wait rather than deleting an unknown lock and racing an active
install. No trap here to auto-release it: this file is sourced into the caller's
shell, and a trap set here would attach to that shell, not just this function.

#### Arguments

* **$1** (string): Lock directory path to create.

#### Exit codes

* **0**: Lock acquired.
* **1**: Timed out after 30s waiting for the lock.

### _rnf_atomic_install

Copy a staged dist tree into place atomically: builds in a scratch
dir next to the destination first, then rm+mv swaps it into place — a failed
copy only ever corrupts the scratch dir, never leaves a partially-overwritten
install.

#### Arguments

* **$1** (string): Source dir (a staged dist tree).
* **$2** (string): Destination dist path.

#### Exit codes

* **0**: Install swapped into place successfully.
* **1**: A step failed; destination is left untouched or removed, never partial.

### _rnf_install_config_checkout

Clone the persistent macsetup-config checkout on first install, or
fast-forward an existing checkout, carrying any uncommitted local changes across
on a stash. The checkout lives beside versioned application directories so future
upgrades never replace it.

#### Arguments

* **$1** (string): Product home directory.

#### Exit codes

* **0**: Configuration checkout is current.
* **1**: Git is unavailable, or clone/pull validation failed.

### _rnf_parse_install_args

Parse installer arguments, setting `_RNF_ARCHIVE` from
`--archive <path>`. Returns rather than exits: this file is sourced, so a bad
argument must never kill the caller's shell.

#### Arguments

* **...** (string): Installer arguments.

#### Variables set

* **_RNF_ARCHIVE** (Path): to a release tarball to install from.

#### Exit codes

* **0**: Parsed successfully.
* **1**: Unrecognized or incomplete arguments.

### rnfmac_install

Install macsetup into `~/.rn-forge/macsetup/<version>/`, install or
update macsetup-config, and link `rnfmac` + its completion script. Three modes:
`--archive <path>` unpacks a release tarball already on disk; in-path mode (an
unpacked dist or this repo's checkout sits alongside install.sh) installs
straight from that tree; streaming mode (neither of those) downloads and
verifies the latest release tarball. No-ops if `current` already matches the
target version. Does not touch .zprofile/.zshrc or run bootstrap/sync — see
next-step output.

#### Arguments

* **...** (string): Installer arguments — optionally `--archive <path>`.

#### Exit codes

* **0**: Installed (or already up to date).
* **1**: shkit failed to load, bad arguments, or an install step failed.

