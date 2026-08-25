# shellcheck shell=bash disable=SC2148,SC2317
# specs for commands/version.sh — prints the installed VERSION.

Describe 'version.sh'
BeforeEach 'setup_sandbox'
AfterEach 'cleanup_sandbox'

It 'prints the installed dist VERSION'
install_dist_from_checkout
When run script "${HOME}/.rn-forge/bin/rnfmac" version
The status should be success
The output should include "${CHECKOUT_VERSION}"
End
End
