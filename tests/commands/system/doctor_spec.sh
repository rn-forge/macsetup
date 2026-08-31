# shellcheck shell=bash disable=SC2148,SC2317
# specs for commands/system/doctor.sh — read-only toolchain health check.
# Two scenarios cover both branches of every check: a fully healthy toolchain
# (mocked brew/uv + real dirs) and a fully absent one (nothing installed).

Describe 'system/doctor.sh'
BeforeEach 'setup_sandbox'
AfterEach 'cleanup_sandbox'

stub_healthy_toolchain() {
  mask_real_toolchain
  mkdir -p "${SANDBOX}/mocks"
  cat >"${SANDBOX}/mocks/brew" <<STUB
#!/bin/sh
case "\$1" in
  --version) echo "Homebrew 4.1.0" ;;
  --prefix) echo "${SANDBOX}/homebrew-test" ;;
  *) exit 1 ;;
esac
STUB
  chmod +x "${SANDBOX}/mocks/brew"
  cat >"${SANDBOX}/mocks/uv" <<'STUB'
#!/bin/sh
[ "$1" = --version ] && echo "uv 0.4.0"
STUB
  chmod +x "${SANDBOX}/mocks/uv"
  export PATH="${SANDBOX}/mocks:${PATH}"

  mkdir -p "${HOME}/.oh-my-zsh/custom/plugins/zsh-completions"
  mkdir -p "${HOME}/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
  mkdir -p "${HOME}/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
  mkdir -p "${HOME}/.nvm"
  mkdir -p "${HOME}/.sdkman/bin"
  : >"${HOME}/.sdkman/bin/sdkman-init.sh"

  mkdir -p "${SANDBOX}/homebrew-test"
  git -C "${SANDBOX}/homebrew-test" init -b main -q
  git -C "${SANDBOX}/homebrew-test" config user.name 'ShellSpec'
  git -C "${SANDBOX}/homebrew-test" config user.email 'shellspec@example.invalid'
  git -C "${SANDBOX}/homebrew-test" commit -q --allow-empty -m 'initial'
  return 0
}

It 'hides healthy records by default'
install_dist_from_checkout
stub_healthy_toolchain
When run script "${HOME}/.rn-forge/bin/rnfmac" system doctor
The status should be success
The output should not include 'Homebrew 4.1.0'
The output should not include 'nvm present'
The output should not include 'macsetup current ->'
The output should include '13 ok, 0 warning, 0 drift, 0 error'
End

It '--all includes healthy records'
install_dist_from_checkout
stub_healthy_toolchain
When run script "${HOME}/.rn-forge/bin/rnfmac" system doctor --all
The status should be success
The output should include 'Homebrew 4.1.0'
The output should include "oh-my-zsh plugin 'zsh-completions' present"
The output should include 'oh-my-zsh present'
The output should include 'uv 0.4.0'
The output should include 'nvm present'
The output should include 'sdkman present'
The output should include 'macsetup current ->'
The output should include 'bin/rnfmac linked'
The output should include 'completions/_rnfmac linked'
The output should include 'shkit installed and sourceable'
The output should include 'Homebrew is on a clean base'
End

It 'exits 2 when configured state has drifted'
install_dist_from_checkout
stub_healthy_toolchain
rm -rf "${HOME}/.nvm"
When run script "${HOME}/.rn-forge/bin/rnfmac" system doctor
The status should eq 2
The output should include 'nvm not found'
The output should include '12 ok, 0 warning, 1 drift, 0 error'
End

It 'exits 1 when shkit is missing from the runtime layout'
stub_healthy_toolchain
write_unit_driver "system/doctor.sh" \
  'rm -f "${RNF_HOME}/shkit/current/shkit.sh"' \
  'execute' \
  'report_render' \
  'exit "$(report_exit_code)"'
When run script "${DRIVER}"
The status should eq 1
The error should include 'shkit not found at'
The output should include '9 ok, 0 warning, 1 drift, 3 error'
End

It 'reports a relay-patched Homebrew with --all'
install_dist_from_checkout
stub_healthy_toolchain
git -C "${SANDBOX}/homebrew-test" commit -q --allow-empty -m 'rn-forge: apply Homebrew remote relay'
When run script "${HOME}/.rn-forge/bin/rnfmac" system doctor --all
The status should be success
The output should include 'Homebrew is patched with the remote relay'
End

It 'prints usage for --help'
When run script "${CHECKOUT}/src/commands/system/doctor.sh" --help
The status should be success
The output should include 'usage: rnfmac system doctor [--all] [--json]'
End
End
