# shellcheck shell=bash disable=SC2148,SC2317
# specs for install.sh — the standalone (sourceable) release installer, which
# supports two modes:
#   streaming — no sibling dist next to install.sh, downloads the latest release
#               tarball (the curl stub serves the shkit install.sh double,
#               the staged release tarball, and its .sha256 sidecar)
#   in-path   — an unpacked dist or this repo's checkout sits next to install.sh,
#               installs straight from it, no macsetup tarball download

Describe 'install.sh'
BeforeEach 'setup_install'
AfterEach 'cleanup_sandbox'

setup_install() {
  setup_sandbox
  build_release_tarball # stage v9.9.9 for the curl stub (streaming mode)

  # streaming mode needs a copy with no sibling rnfmac.sh/VERSION — the real
  # src/install.sh always has both, which would trigger in-path mode instead
  STANDALONE_INSTALL_SH="${SANDBOX}/standalone/install.sh"
  mkdir -p "$(dirname "${STANDALONE_INSTALL_SH}")"
  cp "${SHELLSPEC_PROJECT_ROOT}/src/install.sh" "${STANDALONE_INSTALL_SH}"
  INSTALL_SH="${STANDALONE_INSTALL_SH}"
  export INSTALL_SH
}

It 'installs the latest release and installs shkit locally'
rm -rf "${HOME}/.rn-forge/shkit" # exercise the shkit install.sh download path
When run script "${INSTALL_SH}"
The status should be success
The output should include 'distribution installed (current -> v9.9.9)'
The output should include 'rnfmac system init'
The output should include 'add to ~/.zprofile to persist'
The path "${HOME}/.rn-forge/shkit/current/shkit.sh" should be file
The path "${HOME}/.rn-forge/macsetup/v9.9.9" should be directory
The path "${HOME}/.rn-forge/macsetup/current" should be symlink
The path "${HOME}/.rn-forge/bin/rnfmac" should be symlink
The path "${HOME}/.rn-forge/completions/_rnfmac" should be symlink
The contents of file "${HOME}/.rn-forge/macsetup/current/VERSION" should include '9.9.9'
The path "${HOME}/.zprofile" should not be exist
End

It 'is idempotent — a second run no-ops'
install_twice() {
  "${INSTALL_SH}" >/dev/null 2>&1
  "${INSTALL_SH}"
}
When call install_twice
The status should be success
The output should include 'already on the latest release (v9.9.9)'
End

It 'makes rnfmac available in the sourcing shell immediately'
When run zsh -c '. "${INSTALL_SH}" >/dev/null 2>&1 && rnfmac help'
The status should be success
The output should include 'usage: rnfmac'
The output should include 'sync'
End

It 'does not kill the sourcing shell when the download fails'
export RNF_TEST_RELEASE_TARBALL="/nonexistent/macsetup.tar.gz" # curl stub cp fails
When run zsh -c '. "${INSTALL_SH}"; echo "shell-alive rc=$?"'
The status should be success
The output should include 'shell-alive rc=1'
The error should include 'installation failed'
End

It 'fails when the downloaded tarball checksum does not match its sidecar'
export RNF_TEST_CORRUPT_CHECKSUM=1
When run zsh -c '. "${INSTALL_SH}"; echo "shell-alive rc=$?"'
The status should be success
The output should include 'shell-alive rc=1'
The error should include 'checksum mismatch'
End

It 'warns and proceeds when no checksum sidecar is published'
export RNF_TEST_NO_CHECKSUM=1
When run script "${INSTALL_SH}"
The status should be success
The output should include 'no checksum found'
The output should include 'distribution installed (current -> v9.9.9)'
End

It 'installs in-path from a sibling checkout without downloading the macsetup tarball'
# CHECKOUT's own VERSION (CHECKOUT_VERSION) differs from the streaming fixture (9.9.9)
# staged above — installing CHECKOUT_VERSION here proves the tarball download was
# skipped entirely
When run script "${CHECKOUT}/src/install.sh"
The status should be success
The output should include "distribution installed (current -> v${CHECKOUT_VERSION})"
The path "${HOME}/.rn-forge/macsetup/v${CHECKOUT_VERSION}" should be directory
The contents of file "${HOME}/.rn-forge/macsetup/current/VERSION" should include "${CHECKOUT_VERSION}"
End

It 'in-path re-run from the already-installed dist is idempotent'
"${CHECKOUT}/src/install.sh" >/dev/null 2>&1
When run script "${HOME}/.rn-forge/macsetup/current/install.sh"
The status should be success
The output should include "already on the latest release (v${CHECKOUT_VERSION})"
End

It 'installs shkit from a local bundle, skipping curl, when RNF_SHKIT_INSTALL_BUNDLE is set'
rm -rf "${HOME}/.rn-forge/shkit"
bundle_stage="${SANDBOX}/shkit-bundle-stage"
mkdir -p "${bundle_stage}"
cp "${FIXTURES}/shkit-install.sh" "${bundle_stage}/install.sh"
bundle="${SANDBOX}/shkit.tar.gz"
tar -czf "${bundle}" -C "${bundle_stage}" .
export RNF_SHKIT_INSTALL_BUNDLE="${bundle}"
When run script "${CHECKOUT}/src/install.sh"
The status should be success
The output should include "distribution installed (current -> v${CHECKOUT_VERSION})"
The path "${HOME}/.rn-forge/shkit/current/shkit.sh" should be file
End

It 'does not kill the sourcing shell when RNF_SHKIT_INSTALL_BUNDLE fails to extract'
rm -rf "${HOME}/.rn-forge/shkit"
export RNF_SHKIT_INSTALL_BUNDLE="/nonexistent/shkit.tar.gz"
export CHECKOUT_INSTALL_SH="${CHECKOUT}/src/install.sh"
When run zsh -c '. "${CHECKOUT_INSTALL_SH}"; echo "shell-alive rc=$?"'
The status should be success
The output should include 'shell-alive rc=1'
The error should include 'failed to extract RNF_SHKIT_INSTALL_BUNDLE'
End
End
