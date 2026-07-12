# cleanup.sh

`rnfmac cleanup` — deletes all installed macsetup versions except the current one.

## Overview

Removes every version directory under ~/.rn-forge/macsetup/ other than the one
`current` points to. Upgrade/install never prune old versions themselves (that's
what makes rollback-by-symlink possible), so this is the explicit opt-in to
reclaim that disk space.
Version: 1.0
Author: Rohit Narayanan

## Index

* [execute](#execute)

### execute

Run `rnfmac cleanup`: delete every version dir under PRODUCT_HOME
except the one `current` resolves to. Prompts for confirmation first
(see shkit's `confirm` — bypass with RNF_SKIP_CONFIRMATIONS=1).

_Function has no arguments._

#### Exit codes

* **0**: Always, including when there was nothing to remove.
* **1**: No current install found, or the user declined confirmation.

#### Output on stdout

* One line per version removed, plus a summary.

