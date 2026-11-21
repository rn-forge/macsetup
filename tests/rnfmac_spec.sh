# shellcheck shell=bash disable=SC2148,SC2317
# specs for the rnfmac dispatcher

Describe 'rnfmac dispatcher'
BeforeEach 'setup_sandbox'
AfterEach 'cleanup_sandbox'

It 'lists top-level sub-commands and groups when run without arguments'
When run script "${CHECKOUT}/shell/rnfmac.sh"
The status should be success
The output should include 'usage: rnfmac'
The output should include 'sync'
The output should include 'doctor'
The output should include 'upgrade'
The output should include 'version'
The output should include 'system ...'
The output should include 'profile ...'
The output should include 'brew ...'
The output should include 'config ...'
End

It 'shows usage for --help'
When run script "${CHECKOUT}/shell/rnfmac.sh" --help
The status should be success
The output should include 'usage: rnfmac'
End

It 'fails with usage on an unknown sub-command'
When run script "${CHECKOUT}/shell/rnfmac.sh" bogus
The status should equal 1
The stderr should include "unknown sub-command 'bogus'"
The stderr should include 'usage: rnfmac'
End

It 'maps hyphenated sub-commands to underscored scripts and passes arguments through'
printf '#!/bin/sh\necho "args: $*"\n' >"${CHECKOUT}/shell/commands/dummy_echo.sh"
chmod +x "${CHECKOUT}/shell/commands/dummy_echo.sh"
When run script "${CHECKOUT}/shell/rnfmac.sh" dummy-echo one two
The status should be success
The output should equal 'args: one two'
End

It 'prints a group usage when the group is invoked without a sub-command'
When run script "${CHECKOUT}/shell/rnfmac.sh" system
The status should be success
The output should include 'usage: rnfmac system <sub-command>'
The output should include 'init'
The output should include 'sync'
The output should include 'doctor'
End

It 'dispatches to a two-level group sub-command and passes arguments through'
mkdir -p "${CHECKOUT}/shell/commands/dummy_group"
printf '#!/bin/sh\necho "args: $*"\n' >"${CHECKOUT}/shell/commands/dummy_group/dummy_echo.sh"
chmod +x "${CHECKOUT}/shell/commands/dummy_group/dummy_echo.sh"
When run script "${CHECKOUT}/shell/rnfmac.sh" dummy-group dummy-echo one two
The status should be success
The output should equal 'args: one two'
End

It 'fails with group usage on an unknown group sub-command'
When run script "${CHECKOUT}/shell/rnfmac.sh" system bogus
The status should equal 1
The stderr should include "unknown sub-command 'system bogus'"
The stderr should include 'usage: rnfmac system <sub-command>'
End

It 'never dispatches to the reserved "lib" name, even when the helper is executable'
chmod +x "${CHECKOUT}/shell/commands/config/lib.sh"
When run script "${CHECKOUT}/shell/rnfmac.sh" config lib
The status should be failure
The error should include "unknown sub-command 'config lib'"
End

It 'never offers "lib" as a group sub-command'
When run script "${CHECKOUT}/shell/rnfmac.sh" config --help
The status should be success
The output should include 'pull'
The output should not include 'lib'
End

End
