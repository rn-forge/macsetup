# shellcheck shell=bash disable=SC2148,SC2317
# specs for commands/doctor.sh — meta sweep across system doctor, profile check,
# and brew diff. The sandbox has no real Homebrew/oh-my-zsh plugins/uv/nvm/sdkman,
# so system doctor always reports drift here; this exercises the "continue through
# all three groups, aggregate PROBLEMS" behavior rather than a fully healthy run.

Describe 'doctor.sh'
BeforeEach 'setup_doctor'
AfterEach 'cleanup_sandbox'

setup_doctor() {
  setup_sandbox
  mask_real_toolchain
  # a brew mock that never touches the network or real system state, and
  # reports no drift so this test only exercises "some group failed" via
  # system doctor (missing brew/nvm/sdkman), not a brew failure too
  mkdir -p "${SANDBOX}/mocks"
  cat >"${SANDBOX}/mocks/brew" <<'STUB'
#!/bin/sh
if [ "$1" = --version ]; then
  echo "Homebrew 4.1.0"
  exit 0
fi
if [ "$1" = bundle ] && [ "$2" = check ]; then
  exit 0
fi
if [ "$1" = bundle ] && [ "$2" = cleanup ]; then
  exit 0
fi
exit 1
STUB
  chmod +x "${SANDBOX}/mocks/brew"
  export PATH="${SANDBOX}/mocks:${PATH}"
  return 0
}

It 'runs all three groups and reports failure when any group has drift'
install_dist_from_checkout
run_profile_sync_from_checkout >/dev/null 2>&1
When run script "${HOME}/.rn-forge/bin/rnfmac" doctor
The status should be failure
The output should include 'nvm not found'
The output should include 'profile check passed'
The output should include 'no drift — installed packages match the Brewfile'
End
End
