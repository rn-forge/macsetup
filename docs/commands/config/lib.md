# lib.sh

Shared helpers for the `config` command group. Not dispatchable.

## Overview

Clone macsetup-config when upgrading an installation that predates
the external config checkout, otherwise validate the existing checkout.

## Index

* [ensure_config_checkout](#ensure_config_checkout)
* [require_config_checkout](#require_config_checkout)
* [update_config_checkout](#update_config_checkout)

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

### update_config_checkout

Fast-forward the config checkout onto `origin/<branch>`, carrying any
uncommitted local changes across the update on a stash. Local edits and a moved
remote are the normal case here, not an error — the checkout is a working copy that
`sync`/`upgrade` update behind the user's back, so refusing either side would
deadlock `pull` (wants a clean tree) against `push` (wants an up-to-date HEAD).
Only genuine divergence — local commits absent from the remote — is refused.

_Function has no arguments._

#### Exit codes

* **0**: The checkout is at `origin/<branch>` with local changes intact.
* **1**: The checkout diverged, could not fast-forward, or the stash conflicted.

