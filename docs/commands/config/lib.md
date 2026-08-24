# lib.sh

Shared helpers for the `config` command group. Not dispatchable.

## Overview

Verify that the macsetup-config checkout exists and is on `main`.

## Index

* [require_config_checkout](#require_config_checkout)
* [require_clean_config](#require_clean_config)

### require_config_checkout

Verify that the macsetup-config checkout exists and is on `main`.

_Function has no arguments._

#### Exit codes

* **0**: The checkout is valid and on the expected branch.
* **1**: The checkout is missing, invalid, or on another branch.

### require_clean_config

Fail when the config checkout contains tracked or untracked changes.

_Function has no arguments._

#### Exit codes

* **0**: The checkout is clean.
* **1**: Local changes are present.

