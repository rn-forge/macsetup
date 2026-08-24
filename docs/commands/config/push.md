# push.sh

`rnfmac config push` — commit and publish configuration changes.

## Overview

Publishes local macsetup-config changes directly to the linear main branch.
Fast-forwards onto origin/main first (carrying the local changes across) so a
remote that moved on is not a reason to fail. Requires an explicit commit
message and refuses to merge, rebase, or force-push.
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

Fast-forward onto origin/main, then commit all config checkout
changes and push them.

_Function has no arguments._

#### Exit codes

* **1**: No changes exist, or the checkout could not be brought up to date.

