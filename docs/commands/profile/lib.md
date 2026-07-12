# lib.sh

Shared helpers for the `profile` command group. Not a sub-command itself.

## Overview

Shared helpers for the profile group — sourced by commands/profile/sync.sh and
commands/profile/check.sh. Not a sub-command itself: rnfmac's dispatcher skips any
"lib.sh" when listing a group's sub-commands.
Version: 1.0
Author: Rohit Narayanan

## Index

* [render_profile_content](#render_profile_content)

### render_profile_content

Render the shared + host `profile.zsh` (host wins by coming last)
into the combined content that `profile/sync.sh` installs.

_Function has no arguments._

#### Output on stdout

* The rendered profile.zsh content, with marker headers.

