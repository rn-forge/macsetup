# shellcheck shell=bash disable=SC2148,SC2317
# specs for commands/profile/check.sh — read-only profile drift report.

Describe 'profile/check.sh'
BeforeEach 'setup_sandbox'
AfterEach 'cleanup_sandbox'

It 'hides healthy records by default'
install_dist_from_checkout
run_profile_sync_from_checkout >/dev/null 2>&1
When run script "${HOME}/.rn-forge/bin/rnfmac" profile check
The status should be success
The output should not include 'rendered profile.zsh is up to date'
The output should not include '.zprofile is patched'
The output should not include '.zshrc is patched'
The output should include '3 ok, 0 warning, 0 drift, 0 error'
End

It '--all includes healthy records'
install_dist_from_checkout
run_profile_sync_from_checkout >/dev/null 2>&1
When run script "${HOME}/.rn-forge/bin/rnfmac" profile check --all
The status should be success
The output should include 'rendered profile.zsh is up to date'
The output should include '.zprofile is patched'
The output should include '.zshrc is patched'
End

It 'warns but succeeds when there is no profile for the current host'
install_dist_from_checkout
rm -rf "${HOME}/.rn-forge/macsetup/config/hosts/testhost"
When run script "${HOME}/.rn-forge/bin/rnfmac" profile check
The status should be success
The output should include "no profile for host 'testhost'"
The output should include '0 ok, 1 warning, 0 drift, 0 error'
End

It 'flags a stale rendered profile.zsh'
install_dist_from_checkout
run_profile_sync_from_checkout >/dev/null 2>&1
printf '\n# drift\n' >>"${HOME}/.rn-forge/macsetup/config/shared/profile.zsh"
When run script "${HOME}/.rn-forge/bin/rnfmac" profile check
The status should eq 2
The output should include 'rendered profile.zsh is stale'
End

It 'flags a missing rendered profile.zsh'
install_dist_from_checkout
When run script "${HOME}/.rn-forge/bin/rnfmac" profile check
The status should eq 2
The output should include 'no rendered profile at'
End

It 'flags missing rc-file patches'
install_dist_from_checkout
run_profile_sync_from_checkout >/dev/null 2>&1
: >"${HOME}/.zprofile"
: >"${HOME}/.zshrc"
When run script "${HOME}/.rn-forge/bin/rnfmac" profile check
The status should eq 2
The output should include '.zprofile is missing the macsetup marker'
The output should include '.zshrc is missing the macsetup marker'
End

It 'emits clean JSONL with the profile group'
install_dist_from_checkout
run_profile_sync_from_checkout >/dev/null 2>&1
When run script "${HOME}/.rn-forge/bin/rnfmac" profile check --json
The status should be success
The output should match pattern '{*'
The output should include '"status":"ok"'
The output should include '"group":"profile"'
The output should not include '[info]'
End

It 'prints usage for --help'
When run script "${CHECKOUT}/src/commands/profile/check.sh" --help
The status should be success
The output should include 'usage: rnfmac profile check [--all] [--json]'
End
End
