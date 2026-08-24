# shellcheck shell=bash disable=SC2148,SC2317
# specs for the persistent macsetup-config checkout lifecycle.

Describe 'config commands'
BeforeEach 'setup_config'
AfterEach 'cleanup_sandbox'

setup_config() {
  setup_sandbox
  install_dist_from_checkout
}

It 'shows checkout status and revision'
When run script "${HOME}/.rn-forge/bin/rnfmac" config status
The status should be success
The output should include 'config:'
The output should include 'revision:'
The output should include 'main'
End

It 'pulls a new linear config commit'
printf '\n# remote update\n' >>"${CONFIG_SEED}/shared/profile.zsh"
git -C "${CONFIG_SEED}" add shared/profile.zsh
git -C "${CONFIG_SEED}" commit -m 'Remote update' >/dev/null
git -C "${CONFIG_SEED}" push origin main >/dev/null 2>&1
When run script "${HOME}/.rn-forge/bin/rnfmac" config pull
The status should be success
The output should include 'macsetup config is current'
The contents of file "${HOME}/.rn-forge/macsetup/config/shared/profile.zsh" should include '# remote update'
End

It 'refuses to pull over local changes'
printf '\n# local update\n' >>"${HOME}/.rn-forge/macsetup/config/shared/profile.zsh"
When run script "${HOME}/.rn-forge/bin/rnfmac" config pull
The status should be failure
The error should include 'has local changes'
End

It 'requires an explicit push message'
When run script "${HOME}/.rn-forge/bin/rnfmac" config push
The status should be failure
The error should include 'usage: rnfmac config push -m <message>'
End

It 'commits and pushes local config changes'
printf '\n# published update\n' >>"${HOME}/.rn-forge/macsetup/config/shared/profile.zsh"
When run script "${HOME}/.rn-forge/bin/rnfmac" config push -m 'Publish test config'
The status should be success
The output should include 'macsetup config published'
The contents of file "${HOME}/.rn-forge/macsetup/config/shared/profile.zsh" should include '# published update'
End
End
