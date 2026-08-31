# Homebrew Remote Relay

Corporate networks can block the CDNs that Homebrew uses. The Remote Relay delegates each download to a trusted host with access, then copies the result back into the local Homebrew cache:

```text
local Mac ──ssh──▶ relay host ──curl──▶ ghcr.io / CDN
    ◀────────scp──────── downloaded artifact
```

When `HOMEBREW_REMOTE_RELAY_ENABLED=1`, `RemoteRelayCurlDownloadStrategy` replaces Homebrew's default curl strategy. It connects to `HOMEBREW_REMOTE_RELAY_HOST`, downloads into a remote temporary file, copies the artifact back, and removes the temporary file.

## Applying the relay

`rnfmac brew relay` applies the payload from `src/homebrew/` to the Apple Silicon Homebrew installation at `/opt/homebrew`:

- `src/homebrew/patches/` patches Homebrew's download strategy, strategy detector, and vendored-download command.
- `src/homebrew/download_strategy/remote_relay_curl_download_strategy.rb` provides the strategy implementation.

The default operation resets Homebrew to a clean upstream base and reapplies every patch. Relay patches are the source of truth; the command never cherry-picks a previously stored relay commit. This prevents an old commit from silently preserving patches against the wrong Homebrew source.

Valid patch files need real context from the current Homebrew worktree, which this repository does not vendor. To change the integration, reset the relay, edit the clean Homebrew worktree, and run `rnfmac brew relay --regen`. Do not hand-edit diff hunks.

```sh
rnfmac brew relay          # apply the current patches
rnfmac brew relay --force  # update a clean base, then reapply unconditionally
rnfmac brew relay --reset  # restore a clean upstream Homebrew worktree
rnfmac brew relay --regen  # regenerate patches from uncommitted Homebrew edits
```

A Homebrew upgrade can overwrite the staged files. Re-run `rnfmac brew relay` afterward.

## Configuration

Set these values in the shared or host profile in `macsetup-config`:

| Variable | Default | Purpose |
| --- | --- | --- |
| `HOMEBREW_REMOTE_RELAY_ENABLED` | `0` | Enable or disable relay downloads. |
| `HOMEBREW_REMOTE_RELAY_HOST` | `rohitnarayanan@rohitmacmini.local` | SSH destination that performs downloads. |
| `HOMEBREW_REMOTE_RELAY_DEBUG` | `1` | Print relay commands as they run. |

The relay check is informational: patched and clean-base Homebrew installations are both valid states.

