# shellcheck shell=bash disable=SC2148,SC2317,SC2034
# specs for commands/profile/sync.sh — integration runs use the sandbox $HOME;
# render/backup logic is unit-tested via Include with brew mocked as a function.

Describe 'profile/sync.sh (integration)'
BeforeEach 'setup_sandbox'
AfterEach 'cleanup_sandbox'

It 'runs against an already-installed dist (installed by install.sh, not by profile sync itself)'
install_dist_from_checkout
When run script "${CHECKOUT}/src/commands/profile/sync.sh"
The status should be success
The output should include 'Profile synced successfully'
The path "${HOME}/.rn-forge/macsetup/v${CHECKOUT_VERSION}" should be directory
The path "${HOME}/.rn-forge/macsetup/current" should be symlink
The path "${HOME}/.rn-forge/bin/rnfmac" should be symlink
The path "${HOME}/.rn-forge/completions/_rnfmac" should be symlink
The contents of file "${HOME}/.rn-forge/macsetup/current/VERSION" should include "${CHECKOUT_VERSION}"
End

It 'renders shared + host profile and copies the Brewfile'
install_dist_from_checkout
When run script "${CHECKOUT}/src/commands/profile/sync.sh"
The status should be success
The output should include 'Profile synced successfully'
The contents of file "${HOME}/.rn-forge/macsetup/profile.zsh" should include 'RNFMAC_PROFILE_LOADED'
The contents of file "${HOME}/.rn-forge/macsetup/profile.zsh" should include 'host overrides: testhost'
The contents of file "${HOME}/.rn-forge/macsetup/profile.zsh" should include 'RNF_TEST_HOST_MARKER'
The path "${HOME}/.rn-forge/macsetup/Brewfile" should be file
End

It 'patches .zprofile and .zshrc with the profile source line'
install_dist_from_checkout
When run script "${CHECKOUT}/src/commands/profile/sync.sh"
The status should be success
The output should include 'Profile synced successfully'
The contents of file "${HOME}/.zprofile" should include '#################### macsetup'
The contents of file "${HOME}/.zprofile" should include "source ${HOME}/.rn-forge/macsetup/profile.zsh"
The contents of file "${HOME}/.zshrc" should include "source ${HOME}/.rn-forge/macsetup/profile.zsh"
End

It 'is idempotent — a second run does not duplicate the rc blocks'
sync_twice_and_count() {
  run_profile_sync_from_checkout >/dev/null 2>&1
  run_profile_sync_from_checkout >/dev/null 2>&1
  echo "zprofile-markers:$(grep -c '#################### macsetup' "${HOME}/.zprofile")"
  echo "zshrc-markers:$(grep -c '#################### macsetup' "${HOME}/.zshrc")"
}
When call sync_twice_and_count
The status should be success
The output should include 'zprofile-markers:1'
The output should include 'zshrc-markers:1'
End

It 'completes the .zprofile block when an older marker block is missing the source line'
seed_and_sync() {
  local stale_line="export SOME_OLD_MACSETUP_VAR=1"
  printf '#################### macsetup\n%s\n' "${stale_line}" >>"${HOME}/.zprofile"
  run_profile_sync_from_checkout >/dev/null 2>&1
  echo "markers:$(grep -c '#################### macsetup' "${HOME}/.zprofile")"
  echo "stale-lines:$(grep -cF "${stale_line}" "${HOME}/.zprofile")"
  grep -qF "source ${HOME}/.rn-forge/macsetup/profile.zsh" "${HOME}/.zprofile" && echo "profile-line:present"
}
When call seed_and_sync
The status should be success
The output should include 'markers:1'
The output should include 'stale-lines:1'
The output should include 'profile-line:present'
End

It 'fails clearly when the host has no profile directory'
install_dist_from_checkout
rm -rf "${CHECKOUT}/src/profiles/testhost" "${HOME}/.rn-forge/macsetup/current/profiles/testhost"
When run script "${CHECKOUT}/src/commands/profile/sync.sh"
The status should be failure
The output should include "no profile for host 'testhost'"
End

It 'runs from the installed dist without re-copying (current stays on its version)'
run_profile_sync_from_checkout >/dev/null 2>&1
When run script "${HOME}/.rn-forge/bin/rnfmac" profile sync
The status should be success
The output should include 'Profile synced successfully'
The contents of file "${HOME}/.rn-forge/macsetup/current/VERSION" should include "${CHECKOUT_VERSION}"
End
End

Describe 'profile/sync.sh (unit, via sandbox driver)'
BeforeEach 'setup_sandbox'
AfterEach 'cleanup_sandbox'

It 'render_profile writes shared content before host overrides'
mkdir -p "${SANDBOX}/product/current/profiles/shared" "${SANDBOX}/product/current/profiles/testhost"
echo 'echo shared-part' >"${SANDBOX}/product/current/profiles/shared/profile.zsh"
echo '# aliases' >"${SANDBOX}/product/current/profiles/shared/aliases.zsh"
echo 'echo host-part' >"${SANDBOX}/product/current/profiles/testhost/profile.zsh"
echo '# brewfile' >"${SANDBOX}/product/current/profiles/testhost/Brewfile"
write_unit_driver \
  'profile/sync.sh' \
  "PRODUCT_HOME='${SANDBOX}/product'" \
  "HOST_NAME='testhost'" \
  'render_profile' \
  "shared_line=\$(grep -n 'shared-part' '${SANDBOX}/product/profile.zsh' | cut -d: -f1)" \
  "host_line=\$(grep -n 'host-part' '${SANDBOX}/product/profile.zsh' | cut -d: -f1)" \
  'if [ -n "${shared_line}" ] && [ -n "${host_line}" ] && [ "${shared_line}" -lt "${host_line}" ]; then echo order:shared-first; else echo order:wrong; fi'
When run script "${DRIVER}"
The status should be success
The output should include 'Rendering profile'
The output should include 'order:shared-first'
The path "${SANDBOX}/product/Brewfile" should be file
End
End
