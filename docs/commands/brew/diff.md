# diff.sh

`rnfmac brew diff` — read-only Homebrew drift report.

## Overview

Report drift between installed Homebrew packages and the host Brewfile.
--write updates the Brewfile in the persistent macsetup-config checkout.
Exit 0 no drift, 1 drift/problems found.
Version: 1.0
Author: Rohit Narayanan

## Index

* [usage](#usage)
* [parse_args](#parse_args)
* [report_diff](#report_diff)
* [write_brewfile](#write_brewfile)
* [execute](#execute)

### usage

Print `rnfmac brew diff` usage.

_Function has no arguments._

#### Output on stdout

* The usage text.

### parse_args

Parse CLI args, setting `WRITE_FLAG` and handling `-h`/`--help`.

#### Arguments

* **$1** (string): Optional flag: `--write`, `-h`/`--help`/`help`, or empty.

#### Variables set

* **WRITE_FLAG** (Set): to 1 if `--write` was passed.

#### Exit codes

* **0**: Parsed successfully, or help was requested (also exits the script).
* **1**: Unrecognized argument.

### report_diff

Report drift between installed Homebrew packages and `BREWFILE`.

_Function has no arguments._

#### Exit codes

* **0**: No drift.
* **1**: Drift detected.

### write_brewfile

Dump installed Homebrew package state to the host's Brewfile.
Writes into the persistent macsetup-config checkout.

_Function has no arguments._

#### Exit codes

* **1**: The macsetup-config checkout is missing.

### execute

Run `rnfmac brew diff`: write the Brewfile if `--write` was passed,
otherwise report drift.

_Function has no arguments._

