# relay.sh

`rnfmac brew relay` — (re)applies the Homebrew Remote Relay patches.

## Overview

(Re)apply the Homebrew Remote Relay patches — patches are the single source of
truth. All git operations run against the local Homebrew install at
HOMEBREW_PREFIX (/opt/homebrew — the relay only supports Apple Silicon Macs).
Every apply resets Homebrew to its clean base and re-applies the payload
patches fresh, rather than cherry-picking a stored commit.
Version: 3.0
Author: Rohit Narayanan

## Index

* [usage](#usage)
* [parse_args](#parse_args)
* [ensure_compatible_system](#ensure_compatible_system)
* [ensure_homebrew_repo](#ensure_homebrew_repo)
* [brew_git](#brew_git)
* [brew_git_with_identity](#brew_git_with_identity)
* [head_is_relay_commit](#head_is_relay_commit)
* [reset_homebrew_to_clean_base](#reset_homebrew_to_clean_base)
* [checkout_root](#checkout_root)
* [apply_relay](#apply_relay)
* [ensure_relay_applied](#ensure_relay_applied)
* [force_relay](#force_relay)
* [reset_relay](#reset_relay)
* [regen_patches](#regen_patches)
* [execute](#execute)

### usage

Print `rnfmac brew relay` usage.

_Function has no arguments._

#### Output on stdout

* The usage text.

### parse_args

Parse CLI args, setting the mode flags and handling `-h`/`--help`.
`--force` and `--reset` are mutually exclusive.

#### Arguments

* **...** (string): Flags: `--force`, `--reset`, `--regen`, `-h`/`--help`/`help`.

#### Variables set

* **FORCE_FLAG** (Set): to 1 if `--force` was passed.
* **RESET_FLAG** (Set): to 1 if `--reset` was passed.
* **REGEN_FLAG** (Set): to 1 if `--regen` was passed.

#### Exit codes

* **0**: Parsed successfully, or help was requested (also exits the script).
* **1**: Unrecognized argument, or `--force`+`--reset` both passed.

### ensure_compatible_system

Guard: exit unless `HOMEBREW_PREFIX` exists (Apple Silicon only).

_Function has no arguments._

#### Exit codes

* **1**: `HOMEBREW_PREFIX` does not exist.

### ensure_homebrew_repo

Guard: exit unless `HOMEBREW_PREFIX` is itself the root of a git
repository — refuses to run destructive resets against a repo larger than
`HOMEBREW_PREFIX` (e.g. nested inside another checkout).

_Function has no arguments._

#### Exit codes

* **1**: Not a git repo, or its root isn't `HOMEBREW_PREFIX`.

### brew_git

Run a git command scoped to `HOMEBREW_PREFIX`.

#### Arguments

* **...** (string): Git subcommand and arguments.

### brew_git_with_identity

Run a git command scoped to `HOMEBREW_PREFIX`, with a fixed
`rn-forge` committer identity (needed for `commit` — the real user's git
identity may not be configured for this repo).

#### Arguments

* **...** (string): Git subcommand and arguments.

### head_is_relay_commit

Test whether HEAD in `HOMEBREW_PREFIX` is the relay's own commit.

_Function has no arguments._

#### Exit codes

* **0**: HEAD's subject matches `RELAY_COMMIT_SUBJECT`.
* **1**: It does not.

### reset_homebrew_to_clean_base

Reset `HOMEBREW_PREFIX` back to its clean upstream base: drops the
relay commit if present (else a plain hard reset), then removes the relay's
download-strategy file (untracked, so `reset --hard` alone wouldn't remove it).

_Function has no arguments._

### checkout_root

Print the git checkout root containing `SRC_ROOT`, if any.

_Function has no arguments._

#### Output on stdout

* The checkout's top-level path, or nothing if `SRC_ROOT` isn't in a git checkout.

### apply_relay

Reset Homebrew to its clean base, copy in the relay's download
strategy, apply the payload patches (3-way merge), and commit — the single
codepath every apply mode (default, `--force`) funnels through. On conflict,
resets back to clean base and exits rather than leaving a half-patched tree.

_Function has no arguments._

#### Exit codes

* **1**: A patch failed to apply cleanly (conflicts reported above).

### ensure_relay_applied

Default mode: apply the relay only if it isn't already applied.

_Function has no arguments._

### force_relay

`--force` mode: reset to clean base, `brew update`, then
unconditionally reapply and commit the relay patches.

_Function has no arguments._

### reset_relay

`--reset` mode: hard reset Homebrew back to its clean upstream base.

_Function has no arguments._

### regen_patches

`--regen` mode: regenerate the patch files in `PATCH_PATH` from the
diff between HEAD and a hand-edited clean-base Homebrew worktree at
`HOMEBREW_PREFIX`. Requires a git checkout and a non-relay HEAD.

_Function has no arguments._

#### Exit codes

* **1**: Not run from a git checkout, or HEAD is already the relay commit.

### execute

Run `rnfmac brew relay`: validate the system/repo, then dispatch to
the mode selected by `REGEN_FLAG`/`RESET_FLAG`/`FORCE_FLAG` (default: ensure
the relay is applied).

_Function has no arguments._

