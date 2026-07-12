# shellcheck shell=bash disable=SC2148,SC2317
# specs for commands/sync.sh — the everyday composer (profile -> brew -> system).
# RNFMAC_SYNC_PROFILES_ONLY=1 is set by the sandbox as a safety net, so these runs
# never reach brew/runtimes; they only verify the profile leg and the skip message.

Describe 'sync.sh (composer)'
BeforeEach 'setup_sandbox'
AfterEach 'cleanup_sandbox'

It 'runs profile sync and skips brew/system when RNFMAC_SYNC_PROFILES_ONLY is set'
install_dist_from_checkout
When run script "${CHECKOUT}/src/commands/sync.sh"
The status should be success
The output should include 'Profile synced successfully'
The output should include 'loading macsetup profile'
The output should include 'skipping brew and system sync'
The path "${HOME}/.rn-forge/macsetup/current" should be symlink
End
End
