# shellcheck shell=bash disable=SC2148,SC2317
# specs for the rnfmac dispatcher

Describe 'rnfmac dispatcher'
BeforeEach 'setup_sandbox'
AfterEach 'cleanup_sandbox'

It 'lists top-level sub-commands and groups when run without arguments'
When run script "${CHECKOUT}/src/rnfmac.sh"
The status should be success
The output should include 'usage: rnfmac'
The output should include 'sync'
The output should include 'doctor'
The output should include 'upgrade'
The output should include 'version'
The output should include 'system ...'
The output should include 'profile ...'
The output should include 'brew ...'
End

It 'shows usage for --help'
When run script "${CHECKOUT}/src/rnfmac.sh" --help
The status should be success
The output should include 'usage: rnfmac'
End

It 'fails with usage on an unknown sub-command'
When run script "${CHECKOUT}/src/rnfmac.sh" bogus
The status should equal 1
The stderr should include "unknown sub-command 'bogus'"
The stderr should include 'usage: rnfmac'
End

It 'maps hyphenated sub-commands to underscored scripts and passes arguments through'
printf '#!/bin/sh\necho "args: $*"\n' >"${CHECKOUT}/src/commands/dummy_echo.sh"
chmod +x "${CHECKOUT}/src/commands/dummy_echo.sh"
When run script "${CHECKOUT}/src/rnfmac.sh" dummy-echo one two
The status should be success
The output should equal 'args: one two'
End

It 'prints a group usage when the group is invoked without a sub-command'
When run script "${CHECKOUT}/src/rnfmac.sh" system
The status should be success
The output should include 'usage: rnfmac system <sub-command>'
The output should include 'init'
The output should include 'sync'
The output should include 'doctor'
End

It 'dispatches to a two-level group sub-command and passes arguments through'
mkdir -p "${CHECKOUT}/src/commands/dummy_group"
printf '#!/bin/sh\necho "args: $*"\n' >"${CHECKOUT}/src/commands/dummy_group/dummy_echo.sh"
chmod +x "${CHECKOUT}/src/commands/dummy_group/dummy_echo.sh"
When run script "${CHECKOUT}/src/rnfmac.sh" dummy-group dummy-echo one two
The status should be success
The output should equal 'args: one two'
End

It 'fails with group usage on an unknown group sub-command'
When run script "${CHECKOUT}/src/rnfmac.sh" system bogus
The status should equal 1
The stderr should include "unknown sub-command 'system bogus'"
The stderr should include 'usage: rnfmac system <sub-command>'
End
End
