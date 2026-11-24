# Runtime layout

## Product home

`$RNF_HOME` (`~/.rn-forge` when unset or empty) is the shared runtime home for
the rn-forge product family. Its normative layout is the contract
[The rn-forge home](https://github.com/rn-forge/pykit/blob/main/packages/rn-forge-tooling/docs/guides/home.md),
owned by pykit. macsetup's own parts of it are `macsetup/versions/<version>/`,
`macsetup/config/` and `macsetup/profile.zsh`. Each product uses versioned
installations and a stable `current` symlink:

```text
~/.rn-forge/
├── env.sh
├── bin/
│   └── rnfmac
├── completions/
│   └── _rnfmac
└── macsetup/
    ├── current -> versions/X.Y.Z
    ├── versions/
    │   ├── X.Y.Z/
    │   └── A.B.C/
    ├── config/
    └── profile.zsh
```

Installing, upgrading, or rolling back changes which version `current` points
to. The links under `bin/` and `completions/` continue to resolve through it.
`rnfmac self cleanup` removes every installed macsetup version except the target
of `current`.

The persistent `config/` checkout and rendered `profile.zsh` are deliberately
outside every version directory. Changing the installed release therefore never
overwrites machine configuration.

`env.sh` is written by `self install`; it puts `bin/` on `PATH` and
`completions/` on `fpath`, and the rendered `profile.zsh` sources it.

## Installation and upgrade

`bootstrap.sh` is sourceable and is fetched from the default branch. It installs
Homebrew and uv when missing, then runs `rnfmac self install`, from the latest
GitHub release or from a local archive supplied with `--archive` and
`--version`. `rnfmac self upgrade` uses the same release layout.

An upgrade never applies configuration. Run `rnfmac sync` separately after
reviewing it. A local archive can intentionally move to an older build.
