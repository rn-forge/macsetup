# pull.sh

`rnfmac config pull` — fast-forward the configuration checkout.

## Overview

Clones the persistent macsetup-config checkout when absent, otherwise
fast-forwards it to origin/main. Uncommitted local changes are carried across
the update rather than refused; it never merges, rebases, or overwrites them.
Refuses only a divergent checkout (local commits absent from origin).
Version: 1.0
Author: Rohit Narayanan

## Index

* [execute](#execute)

### execute

Ensure the checkout exists, then fast-forward it onto `origin/main`,
preserving any uncommitted local changes.

_Function has no arguments._

#### Exit codes

* **0**: Configuration is current.
* **1**: Checkout validation or update failed.

