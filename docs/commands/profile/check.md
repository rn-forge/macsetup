# check.sh

`rnfmac profile check` — read-only profile drift report.

## Overview

Read-only report: does the installed profile.zsh + rc-file patches match what
profile sync would render? Exit 0 healthy, 1 drift/problems found.
Version: 1.0
Author: Rohit Narayanan

## Index

* [report_problem](#report_problem)
* [check_host_profile](#check_host_profile)
* [check_rendered_profile](#check_rendered_profile)
* [check_rc_files](#check_rc_files)
* [execute](#execute)

### report_problem

Log a warning and mark the run as having found a problem.

#### Arguments

* **$1** (string): The warning message.

#### Variables set

* **PROBLEMS** (Set): to 1.

### check_host_profile

Check that a profile exists for the current host.

_Function has no arguments._

#### Exit codes

* **1**: No profile for this host (reported via `report_problem`).

### check_rendered_profile

Check the installed `profile.zsh` matches a freshly-rendered copy.

_Function has no arguments._

### check_rc_files

Check `.zprofile` and `.zshrc` both carry the macsetup marker + source line.

_Function has no arguments._

### execute

Run `rnfmac profile check`: host-profile existence, then (if that
passed) rendered-profile freshness and rc-file patch status.

_Function has no arguments._

#### Variables set

* **PROBLEMS** (Left): at 1 if any check reported a problem.

