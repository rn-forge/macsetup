# push.sh

`rnfmac config push` — commit and publish configuration changes.

## Overview

Publishes local macsetup-config changes directly to the linear main branch.
Requires an explicit commit message and refuses to merge, rebase, or force-push.
Version: 1.0
Author: Rohit Narayanan

## Index

* [parse_args](#parse_args)
* [execute](#execute)

### parse_args

Parse `-m <message>` or `--message <message>`.

#### Arguments

* **...** (string): Command arguments.

#### Exit codes

* **1**: Arguments are missing or invalid.

### execute

Commit all config checkout changes and push them to origin/main.

_Function has no arguments._

#### Exit codes

* **1**: No changes exist, or local main is not equal to origin/main.

