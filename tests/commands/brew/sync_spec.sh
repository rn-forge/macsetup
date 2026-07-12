# shellcheck shell=bash disable=SC2148,SC2317,SC2034
# specs for commands/brew/sync.sh — sync_packages is unit-tested via Include with brew mocked.

Describe 'brew/sync.sh (unit, via sandbox driver)'
BeforeEach 'setup_sandbox'
AfterEach 'cleanup_sandbox'

It 'sync_packages drives brew bundle install + cleanup against the host Brewfile'
mkdir -p "${SANDBOX}/mocks"
printf '#!/bin/sh\necho "brew $*"\n' >"${SANDBOX}/mocks/brew"
chmod +x "${SANDBOX}/mocks/brew"
write_unit_driver \
  'brew/sync.sh' \
  "export PATH='${SANDBOX}/mocks':\"\${PATH}\"" \
  "BREWFILE='${SANDBOX}/product/Brewfile'" \
  'sync_packages'
When run script "${DRIVER}"
The status should be success
The output should include "brew bundle install --file=${SANDBOX}/product/Brewfile --verbose --force"
The output should include "brew bundle cleanup --file=${SANDBOX}/product/Brewfile --verbose --force"
The output should include 'brew list'
End
End
