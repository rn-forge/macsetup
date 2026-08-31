# Configuration model

Changing machine configuration lives in the separate `rn-forge/macsetup-config` repository. It is cloned persistently to `~/.rn-forge/macsetup/config` (`CONFIG_HOME`), outside every versioned macsetup installation so an install or upgrade cannot overwrite it.

Configuration is split between common files and directories named after each machine's lowercased short hostname (`hostname | cut -d. -f1`):

```text
macsetup-config/
├── shared/
│   ├── profile.zsh
│   ├── aliases.zsh
│   ├── python-versions
│   ├── node-versions
│   └── java-versions
└── hosts/
    ├── rohitmacbook/
    │   ├── profile.zsh
    │   ├── Brewfile
    │   └── *-versions
    └── rohitmacmini/
```

## Profiles and runtime versions

`rnfmac profile sync` renders the shared profile first and the host profile second into `~/.rn-forge/macsetup/profile.zsh`; host settings therefore win when both assign the same value. It patches both `.zprofile` and `.zshrc` to source the rendered file, backing up existing files first.

Runtime-version files merge rather than override. Entries from shared and host files are combined with duplicates removed and order preserved. The first combined entry becomes the default, while all entries are installed side by side. At least one shared or host version file must exist for each runtime; macsetup has no fallback version pins.

To add a machine, create `hosts/<hostname>/profile.zsh` and `hosts/<hostname>/Brewfile`, add any host-only runtime versions, publish the change, and run `rnfmac sync` on that machine.

## Updating the checkout

`rnfmac config pull` clones the repository when it is absent. Otherwise it fast-forwards from `origin/main`; it never merges, rebases, or overwrites published history. Uncommitted tracked and untracked changes are carried across on a stash and restored afterward. A diverged checkout or stash conflict fails loudly for manual resolution.

`rnfmac sync` pulls configuration first so new package and runtime declarations apply to the remaining steps. When the checkout did not exist, it bootstraps the checkout and stops without applying it, giving you a chance to inspect the repository before rerunning sync.

Use `rnfmac brew diff --write` to update the current host's Brewfile from installed packages, review the resulting diff, then publish it explicitly:

```sh
rnfmac config status
rnfmac config push -m "Update host config"
```

`rnfmac config reset --force` is the only command that discards local configuration changes. Without `--force`, it reports what would be lost and exits.

