# lib.sh

Shared helpers for the `config` command group. Not dispatchable.

## Overview

Clone macsetup-config when upgrading an installation that predates
the external config checkout, otherwise validate the existing checkout.

## Index

* [ensure_config_checkout](#ensure_config_checkout)
* [require_config_checkout](#require_config_checkout)
* [require_clean_config](#require_clean_config)

### ensure_config_checkout

Clone macsetup-config when upgrading an installation that predates
the external config checkout, otherwise validate the existing checkout.

_Function has no arguments._

#### Exit codes

* **0**: The checkout exists and is on the expected branch.
* **1**: Clone or checkout validation failed.

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

