# shellcheck shell=bash disable=SC2148,SC2317
# specs for commands/profile/check.sh — read-only profile drift report.

Describe 'profile/check.sh'
BeforeEach 'setup_sandbox'
AfterEach 'cleanup_sandbox'

It 'passes when the profile is freshly synced'
install_dist_from_checkout
run_profile_sync_from_checkout >/dev/null 2>&1
When run script "${HOME}/.rn-forge/bin/rnfmac" profile check
The status should be success
The output should include 'rendered profile.zsh is up to date'
The output should include '.zprofile is patched'
The output should include '.zshrc is patched'
The output should include 'profile check passed'
End

It 'fails when there is no profile for the current host'
install_dist_from_checkout
rm -rf "${HOME}/.rn-forge/macsetup/config/hosts/testhost"
When run script "${HOME}/.rn-forge/bin/rnfmac" profile check
The status should be failure
The output should include "no profile for host 'testhost'"
End

It 'flags a stale rendered profile.zsh'
install_dist_from_checkout
run_profile_sync_from_checkout >/dev/null 2>&1
printf '\n# drift\n' >>"${HOME}/.rn-forge/macsetup/config/shared/profile.zsh"
When run script "${HOME}/.rn-forge/bin/rnfmac" profile check
The status should be failure
The output should include 'rendered profile.zsh is stale'
End

It 'flags a missing rendered profile.zsh'
install_dist_from_checkout
When run script "${HOME}/.rn-forge/bin/rnfmac" profile check
The status should be failure
The output should include 'no rendered profile at'
End

It 'flags missing rc-file patches'
install_dist_from_checkout
run_profile_sync_from_checkout >/dev/null 2>&1
: >"${HOME}/.zprofile"
: >"${HOME}/.zshrc"
When run script "${HOME}/.rn-forge/bin/rnfmac" profile check
The status should be failure
The output should include '.zprofile is missing the macsetup marker'
The output should include '.zshrc is missing the macsetup marker'
End
End
