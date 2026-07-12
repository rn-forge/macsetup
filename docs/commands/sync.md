# sync.sh

`rnfmac sync` — the everyday sync command.

## Overview

Composer: profile sync -> brew sync -> system sync, in that order (profile first
so a new dist's Brewfile/pins are what get applied).
Version: 1.0
Author: Rohit Narayanan

## Index

* [execute](#execute)

### execute

Run `rnfmac sync`: profile sync, then (unless
`RNFMAC_SYNC_PROFILES_ONLY` is set) brew sync and system sync.

_Function has no arguments._

#### Exit codes

* **0**: All steps succeeded.
* **1**: A step failed (propagated via `set -e`).

