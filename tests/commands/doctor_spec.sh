# shellcheck shell=bash disable=SC2148,SC2317
# specs for commands/doctor.sh — meta sweep across system doctor, profile check,
# and brew diff. The sandbox has no real Homebrew/oh-my-zsh plugins/uv/nvm/sdkman,
# so system doctor reports drift here; this exercises aggregation across groups.

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
if [ "$1" = --prefix ]; then
  echo "${BREW_TEST_PREFIX}"
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
  export BREW_TEST_PREFIX="${SANDBOX}/homebrew-test"
  mkdir -p "${BREW_TEST_PREFIX}"
  export PATH="${SANDBOX}/mocks:${PATH}"
  return 0
}

run_doctor_with_counts() {
  local output command_status
  output="$("${HOME}/.rn-forge/bin/rnfmac" doctor)"
  command_status=$?
  printf '%s\n' "${output}"
  printf 'summary-lines:%s\n' "$(printf '%s\n' "${output}" | grep -c ' ok, .* warning, .* drift, .* error')"
  printf 'toolchain-headings:%s\n' "$(printf '%s\n' "${output}" | grep -c 'toolchain')"
  printf 'runtime-headings:%s\n' "$(printf '%s\n' "${output}" | grep -c 'runtime')"
  printf 'profile-headings:%s\n' "$(printf '%s\n' "${output}" | grep -c 'profile')"
  printf 'packages-headings:%s\n' "$(printf '%s\n' "${output}" | grep -c 'packages')"
  return "${command_status}"
}

It 'renders one combined report and exits 2 when any group has drift'
install_dist_from_checkout
run_profile_sync_from_checkout >/dev/null 2>&1
When call run_doctor_with_counts
The status should eq 2
The output should include 'nvm not found'
The output should include 'summary-lines:1'
The output should include 'toolchain-headings:1'
The output should include 'runtime-headings:1'
The output should include 'profile-headings:1'
The output should include 'packages-headings:1'
End

It '--json emits only aggregated JSONL records'
install_dist_from_checkout
run_profile_sync_from_checkout >/dev/null 2>&1
When run script "${HOME}/.rn-forge/bin/rnfmac" doctor --json
The status should eq 2
The output should match pattern '{*'
The output should include '"status":'
The output should include '"group":"system"'
The output should include '"group":"profile"'
The output should include '"group":"brew"'
The output should not include '[info]'
End

It 'prints usage for --help'
install_dist_from_checkout
When run script "${HOME}/.rn-forge/bin/rnfmac" doctor --help
The status should be success
The output should include 'usage: rnfmac doctor [--all] [--json]'
End
End
