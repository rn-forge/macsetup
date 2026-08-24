# shellcheck shell=bash disable=SC2148,SC2317
# specs for the persistent macsetup-config checkout lifecycle.

Describe 'config commands'
BeforeEach 'setup_config'
AfterEach 'cleanup_sandbox'

setup_config() {
  setup_sandbox
  install_dist_from_checkout
}

# advance the config origin by one commit, so the installed checkout is behind it
push_remote_commit() {
  printf '\n# remote update\n' >>"${CONFIG_SEED}/shared/profile.zsh"
  git -C "${CONFIG_SEED}" add shared/profile.zsh
  git -C "${CONFIG_SEED}" commit -m 'Remote update' >/dev/null
  git -C "${CONFIG_SEED}" push origin main >/dev/null 2>&1
}

It 'shows checkout status and revision'
When run script "${HOME}/.rn-forge/bin/rnfmac" config status
The status should be success
The output should include 'config:'
The output should include 'revision:'
The output should include 'main'
The output should include 'no local changes'
End

It 'shows a diff of unpublished changes'
printf '\n# local update\n' >>"${HOME}/.rn-forge/macsetup/config/shared/profile.zsh"
When run script "${HOME}/.rn-forge/bin/rnfmac" config status
The status should be success
The output should include 'local changes:'
The output should include '+# local update'
The output should include 'rnfmac config push'
End

It 'shows the contents of untracked config files'
printf 'brew "ripgrep"\n' >"${HOME}/.rn-forge/macsetup/config/hosts/testhost/Brewfile.new"
When run script "${HOME}/.rn-forge/bin/rnfmac" config status
The status should be success
The output should include 'Brewfile.new'
The output should include '+brew "ripgrep"'
End

It 'reports incoming commits without pulling them'
push_remote_commit
When run script "${HOME}/.rn-forge/bin/rnfmac" config status
The status should be success
The output should include 'behind origin/main'
The output should include 'Remote update'
The contents of file "${HOME}/.rn-forge/macsetup/config/shared/profile.zsh" should not include '# remote update'
End

It 'pulls a new linear config commit'
push_remote_commit
When run script "${HOME}/.rn-forge/bin/rnfmac" config pull
The status should be success
The output should include 'macsetup config is current'
The contents of file "${HOME}/.rn-forge/macsetup/config/shared/profile.zsh" should include '# remote update'
End

It 'pulls while preserving uncommitted local changes'
push_remote_commit
printf '\n# local update\n' >>"${HOME}/.rn-forge/macsetup/config/hosts/testhost/Brewfile"
When run script "${HOME}/.rn-forge/bin/rnfmac" config pull
The status should be success
The output should include 'macsetup config is current'
The contents of file "${HOME}/.rn-forge/macsetup/config/shared/profile.zsh" should include '# remote update'
The contents of file "${HOME}/.rn-forge/macsetup/config/hosts/testhost/Brewfile" should include '# local update'
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

# the deadlock this pair used to hit: push refused a moved remote, pull refused a
# dirty tree, so neither command could get the checkout out of that state.
It 'pushes local changes onto a remote that moved on'
push_remote_commit
printf '\n# published update\n' >>"${HOME}/.rn-forge/macsetup/config/hosts/testhost/Brewfile"
When run script "${HOME}/.rn-forge/bin/rnfmac" config push -m 'Publish test config'
The status should be success
The output should include 'macsetup config published'
The contents of file "${HOME}/.rn-forge/macsetup/config/shared/profile.zsh" should include '# remote update'
The contents of file "${HOME}/.rn-forge/macsetup/config/hosts/testhost/Brewfile" should include '# published update'
End

It 'syncs over uncommitted config changes instead of failing'
printf '\n# local update\n' >>"${HOME}/.rn-forge/macsetup/config/hosts/testhost/Brewfile"
When run script "${HOME}/.rn-forge/bin/rnfmac" sync
The status should be success
The output should include 'macsetup config is current'
The output should include 'Profile synced successfully'
The contents of file "${HOME}/.rn-forge/macsetup/config/hosts/testhost/Brewfile" should include '# local update'
End
End
