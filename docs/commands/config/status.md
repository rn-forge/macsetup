# status.sh

`rnfmac config status` — show configuration checkout status and local diff.

## Overview

Read-only report on the macsetup-config checkout: where it is, what revision it
sits on, how it compares to origin/main, and the full diff of anything not yet
published — so there is never a reason to run git by hand inside the checkout.
Version: 2.0
Author: Rohit Narayanan

## Index

* [config_git](#config_git)
* [show_identity](#show_identity)
* [show_remote_state](#show_remote_state)
* [show_local_changes](#show_local_changes)
* [execute](#execute)

### config_git

Run a read-only git command in the config checkout with the pager off.

#### Arguments

* **...** (string): The git arguments.

#### Output on stdout

* The command's output.

### show_identity

Print the checkout location, branch, and current revision.

_Function has no arguments._

#### Output on stdout

* The identity block.

### show_remote_state

Fetch origin and report how the checkout compares to it, listing the
commits waiting to be pulled. A fetch failure is reported, not fatal — status
must still work offline.

_Function has no arguments._

#### Output on stdout

* The remote comparison block.

### show_local_changes

Print the full diff of unpublished work: tracked changes against HEAD,
then each untracked file diffed against /dev/null so new files show their contents
too (`git diff` alone would silently omit them).

_Function has no arguments._

#### Output on stdout

* The local-changes block, or nothing beyond a success note when clean.

### execute

Show the branch, revision, remote comparison, and local diff of
macsetup-config.

_Function has no arguments._

