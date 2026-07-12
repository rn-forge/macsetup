# shellcheck shell=bash disable=SC2148,SC2317
# specs for commands/brew/relay.sh — RNFMAC_TEST_HOMEBREW_PREFIX (a shellspec-only seam)
# points the script at a fixture git repo holding dummy managed files, instead of the real
# /opt/homebrew. A real, clean patch *apply* only succeeds against actual Homebrew sources
# (not covered here); the fixture's mismatched content exercises the conflict-handling path
# instead, which resets back to a clean base rather than leaving Homebrew half-patched.
# The ssh/scp relay path itself is out of spec scope.

Describe 'brew/relay.sh'
BeforeEach 'setup_relay'
AfterEach 'cleanup_sandbox'

RELAY_STRATEGY="Library/Homebrew/download_strategy/remote_relay_curl_download_strategy.rb"

setup_relay() {
  setup_sandbox
  export RNFMAC_TEST_HOMEBREW_PREFIX="${SANDBOX}/homebrew"
  HOMEBREW_PREFIX="${RNFMAC_TEST_HOMEBREW_PREFIX}"
  mkdir -p "${HOMEBREW_PREFIX}/Library/Homebrew/cmd" "${HOMEBREW_PREFIX}/Library/Homebrew/download_strategy"
  local managed
  for managed in \
    "Library/Homebrew/download_strategy.rb" \
    "Library/Homebrew/download_strategy/download_strategy_detector.rb" \
    "Library/Homebrew/cmd/vendor-install.sh"; do
    echo "original: ${managed}" >"${HOMEBREW_PREFIX}/${managed}"
  done
  git -C "${HOMEBREW_PREFIX}" init -q
  git -C "${HOMEBREW_PREFIX}" add -A
  git -C "${HOMEBREW_PREFIX}" -c user.name=spec -c user.email=spec@test commit -q -m 'baseline'
}

It 'shows usage for help'
When run script "${CHECKOUT}/src/commands/brew/relay.sh" help
The status should be success
The output should include 'Usage: rnfmac brew relay'
End

It 'rejects unknown flags with usage and non-zero exit'
When run script "${CHECKOUT}/src/commands/brew/relay.sh" --bogus
The status should be failure
The stderr should include 'Usage: rnfmac brew relay'
End

It 'rejects --force and --reset together'
When run script "${CHECKOUT}/src/commands/brew/relay.sh" --force --reset
The status should be failure
The stderr should include 'mutually exclusive'
End

It 'exits with a clear message when the Homebrew prefix does not exist'
export RNFMAC_TEST_HOMEBREW_PREFIX="${SANDBOX}/no-such-homebrew"
When run script "${CHECKOUT}/src/commands/brew/relay.sh"
The status should be failure
The output should include 'not compatible with the Homebrew relay'
The output should include "${SANDBOX}/no-such-homebrew"
End

It 'refuses to operate when the Homebrew prefix is not its own repo root'
export RNFMAC_TEST_HOMEBREW_PREFIX="${HOMEBREW_PREFIX}/Library/Homebrew"
When run script "${CHECKOUT}/src/commands/brew/relay.sh"
The status should be failure
The output should include 'is not the root of its git repository'
End

It '--reset restores managed files to HEAD and removes the relay strategy'
echo 'local modification' >>"${HOMEBREW_PREFIX}/Library/Homebrew/download_strategy.rb"
touch "${HOMEBREW_PREFIX}/${RELAY_STRATEGY}"
When run script "${CHECKOUT}/src/commands/brew/relay.sh" --reset
The status should be success
The output should include 'clean upstream base'
The contents of file "${HOMEBREW_PREFIX}/Library/Homebrew/download_strategy.rb" should equal 'original: Library/Homebrew/download_strategy.rb'
The path "${HOMEBREW_PREFIX}/${RELAY_STRATEGY}" should not be exist
End

It 'reports conflicts and resets Homebrew back to its clean base rather than half-patching'
When run script "${CHECKOUT}/src/commands/brew/relay.sh"
The status should be failure
The stderr should include 'patch does not apply'
The output should include 'reset Homebrew back to its clean base'
The contents of file "${HOMEBREW_PREFIX}/Library/Homebrew/download_strategy.rb" should equal 'original: Library/Homebrew/download_strategy.rb'
The path "${HOMEBREW_PREFIX}/${RELAY_STRATEGY}" should not be exist
End

It 'no-op mode skips with confirmation when already applied'
git -C "${HOMEBREW_PREFIX}" commit -q --allow-empty -m 'rn-forge: apply Homebrew remote relay'
When run script "${CHECKOUT}/src/commands/brew/relay.sh"
The status should be success
The output should include 'already applied'
End

It '--force resets and unconditionally reapplies rather than short-circuiting when already applied'
git -C "${HOMEBREW_PREFIX}" commit -q --allow-empty -m 'rn-forge: apply Homebrew remote relay'
When run script "${CHECKOUT}/src/commands/brew/relay.sh" --force
The status should be failure
The output should include 'Resetting and reapplying'
The stderr should include 'patch does not apply'
End

It '--regen requires a git checkout'
write_regen_driver() {
  DRIVER="${SANDBOX}/regen_driver.zsh"
  {
    echo '#!/bin/zsh'
    echo 'set -eo pipefail'
    echo "export RNFMAC_TEST_HOMEBREW_PREFIX='${HOMEBREW_PREFIX}'"
    echo "exec '${HOME}/.rn-forge/macsetup/current/commands/brew/relay.sh' --regen"
  } >"${DRIVER}"
  chmod +x "${DRIVER}"
}
run_sync_from_checkout >/dev/null 2>&1
write_regen_driver
When run script "${DRIVER}"
The status should be failure
The output should include "'--regen' requires a git checkout"
End
End
