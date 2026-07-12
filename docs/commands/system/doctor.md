# doctor.sh

`rnfmac system doctor` — read-only toolchain health check.

## Overview

Read-only health report for machine toolchain state. Exit 0 healthy, 1 problems found.
Version: 1.0
Author: Rohit Narayanan

## Index

* [report_problem](#report_problem)
* [check_homebrew](#check_homebrew)
* [check_ohmyzsh](#check_ohmyzsh)
* [check_runtime_managers](#check_runtime_managers)
* [check_rn_forge_layout](#check_rn_forge_layout)
* [check_relay_state](#check_relay_state)
* [execute](#execute)

### report_problem

Log a warning and mark the run as having found a problem.

#### Arguments

* **$1** (string): The warning message.

#### Variables set

* **PROBLEMS** (Set): to 1.

### check_homebrew

Check Homebrew and its required oh-my-zsh plugins are installed.

_Function has no arguments._

### check_ohmyzsh

Check oh-my-zsh is installed.

_Function has no arguments._

### check_runtime_managers

Check uv, nvm, and sdkman are installed.

_Function has no arguments._

### check_rn_forge_layout

Check the `~/.rn-forge` runtime layout: macsetup's `current` symlink,
`bin/rnfmac`, `completions/_rnfmac`, and the installed shkit.

_Function has no arguments._

### check_relay_state

Report (informationally, never a problem) whether Homebrew is
currently patched with the remote relay. No-ops if Homebrew or its git repo
isn't present.

_Function has no arguments._

### execute

Run `rnfmac system doctor`: all toolchain checks, in order.

_Function has no arguments._

#### Variables set

* **PROBLEMS** (Left): at 1 if any check reported a problem.

