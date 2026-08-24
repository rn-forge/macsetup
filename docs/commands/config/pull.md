# pull.sh

`rnfmac config pull` — fast-forward the configuration checkout.

## Overview

Updates the persistent macsetup-config checkout from origin/main. Refuses dirty
or divergent checkouts; it never merges, rebases, or overwrites local changes.
Version: 1.0
Author: Rohit Narayanan

## Index

* [execute](#execute)

### execute

Pull `origin/main` with fast-forward-only semantics.

_Function has no arguments._

#### Exit codes

* **0**: Configuration is current.
* **1**: Checkout validation or pull failed.

