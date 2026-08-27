# reset.sh

`rnfmac config reset` — discard local config changes.

## Overview

Hard-resets the macsetup-config checkout to origin/main, discarding any
uncommitted local changes (tracked and untracked). Refuses to run without
`--force` so it never destroys unpublished work by accident; without the
flag it reports what would be discarded and exits non-zero.
Version: 1.0
Author: Rohit Narayanan

## Index

* [parse_args](#parse_args)
* [execute](#execute)

### parse_args

Parse `--force`.

#### Arguments

* **...** (string): Command arguments.

#### Variables set

* **FORCE_FLAG** (Set): to 1 if `--force` was passed.

#### Exit codes

* **1**: An unrecognized argument was passed.

### execute

Hard-reset the config checkout to origin/main and remove
untracked files, discarding all local changes.

_Function has no arguments._

#### Exit codes

* **0**: The checkout is clean and matches origin/main.
* **1**: Local changes exist and `--force` was not passed.

