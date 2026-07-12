# rnfmac.sh

The `rnfmac` command dispatcher.

## Overview

`rnfmac <sub-command> [args ...]` runs commands/<sub_command>.sh.
`rnfmac <group> <sub-command> [args ...]` runs commands/<group>/<sub_command>.sh
when commands/<group>/ is a directory. Dropping a script into commands/ (or a
new commands/<group>/) adds the sub-command with no registration anywhere else —
this file only ever lists what's already on disk.
Version: 2.0
Author: Rohit Narayanan

## Index

* [is_lib_name](#is_lib_name)
* [list_top_level](#list_top_level)
* [list_group](#list_group)
* [usage](#usage)
* [group_usage](#group_usage)

### is_lib_name

"lib" is a reserved name, not a sub-command: a top-level commands/lib/
directory, or a commands/<group>/lib.sh, holds helpers shared within that scope
and gets sourced by the real sub-commands rather than dispatched to directly.

#### Arguments

* **$1** (string): A sub-command or group name to test.

#### Exit codes

* **0**: If `$1` is the reserved name "lib".
* **1**: Otherwise.

### list_top_level

List top-level sub-commands (commands/*.sh) and sub-command groups
(commands/*/), skipping the reserved "lib" name in either position.

#### Output on stdout

* One `  <name>` line per sub-command, one `  <name> ...` line per group.

### list_group

List the sub-commands within one group directory, skipping "lib.sh".

#### Arguments

* **$1** (string): Path to a commands/<group>/ directory.

#### Output on stdout

* One `  <name>` line per sub-command in the group.

### usage

Print top-level usage: `rnfmac <sub-command> [args ...]` plus the
list of available sub-commands and groups.

#### Output on stdout

* The usage text.

### group_usage

Print usage for one sub-command group: `rnfmac <group> <sub-command>
[args ...]` plus the list of sub-commands within that group.

#### Arguments

* **$1** (string): Group name (already underscore-normalized).

#### Output on stdout

* The usage text.

