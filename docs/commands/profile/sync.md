# sync.sh

`rnfmac profile sync` — renders and installs the shell profile.

## Overview

Script to install the macsetup distribution into RNF_HOME and render/patch the shell profile
Run As: local admin
Version: 1.0
Author: Rohit Narayanan

## Index

* [backup](#backup)
* [update_zprofile](#update_zprofile)
* [update_zshrc](#update_zshrc)
* [render_profile](#render_profile)
* [sync_profile](#sync_profile)
* [execute](#execute)

### backup

Back up a file to `RNF_HOME/backup/macsetup/`, timestamped, unless
it's identical to the most recent backup already taken.

#### Arguments

* **$1** (string): Path to the file to back up. No-op if it doesn't exist.

### update_zprofile

Back up and patch `~/.zprofile` to source the rendered profile,
idempotently (single marker guard, appended at end).

_Function has no arguments._

### update_zshrc

Back up and patch `~/.zshrc` to source the rendered profile,
idempotently, inserting the source line before oh-my-zsh.sh loads (plugins=()
must be set before oh-my-zsh.sh reads it, which only .zprofile guarantees for
login shells — a non-login shell, e.g. tmux or a plain `zsh`, sources only
.zshrc, so it needs its own copy too).

_Function has no arguments._

### render_profile

Render shared+host profile.zsh into `PRODUCT_HOME/profile.zsh` and
copy the host's Brewfile into place.

_Function has no arguments._

#### Exit codes

* **1**: No profile exists for the current host.

### sync_profile

Patch .zprofile/.zshrc, install the oh-my-zsh theme, and install
the shared keybindings — everything except rendering profile.zsh itself.

_Function has no arguments._

### execute

Run `rnfmac profile sync`: render the profile, then apply it.

_Function has no arguments._

