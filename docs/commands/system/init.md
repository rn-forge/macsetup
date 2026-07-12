# init.sh

`rnfmac system init` — one-time bootstrap of a new macOS system.

## Overview

Script to bootstrap a new macOS system from scratch
Run As: local admin
Version: 1.0
Author: Rohit Narayanan

## Index

* [usage](#usage)
* [parse_args](#parse_args)
* [activate_homebrew](#activate_homebrew)
* [execute](#execute)
* [setup_homebrew](#setup_homebrew)
* [setup_ohmyzsh](#setup_ohmyzsh)
* [setup_uv](#setup_uv)
* [setup_nvm](#setup_nvm)
* [setup_sdkman](#setup_sdkman)

### usage

Print `rnfmac system init` usage.

_Function has no arguments._

#### Output on stdout

* The usage text.

### parse_args

Parse CLI args, setting `FORCE_FLAG` and handling `-h`/`--help`.

#### Arguments

* **...** (string): Flags: `--force`, `-h`/`--help`/`help`.

#### Variables set

* **FORCE_FLAG** (Set): to 1 if `--force` was passed.

#### Exit codes

* **0**: Parsed successfully, or help was requested (also exits the script).
* **1**: Unrecognized argument.

### activate_homebrew

Load `brew shellenv` into the current shell for the right Homebrew
prefix (Apple Silicon vs Intel).

_Function has no arguments._

### execute

Run `rnfmac system init`: install Homebrew, oh-my-zsh (+ plugins),
uv, nvm, and SDKMAN, in order, skipping (or with `FORCE_FLAG`, reinstalling)
any already present.

_Function has no arguments._

### setup_homebrew

Install Homebrew (or reinstall if `FORCE_FLAG` is set), then
activate it in the current shell.

_Function has no arguments._

### setup_ohmyzsh

Install oh-my-zsh and its zsh-completions/zsh-autosuggestions/
zsh-syntax-highlighting plugins (or reinstall if `FORCE_FLAG` is set).

_Function has no arguments._

### setup_uv

Install uv via Homebrew (or reinstall if `FORCE_FLAG` is set).

_Function has no arguments._

### setup_nvm

Install nvm (or reinstall if `FORCE_FLAG` is set).

_Function has no arguments._

### setup_sdkman

Install SDKMAN (or reinstall if `FORCE_FLAG` is set).

_Function has no arguments._

