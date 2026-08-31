# shellcheck shell=bash disable=SC2148,SC2317
# specs for commands/brew/diff.sh writes into the external config checkout.

Describe 'brew/diff.sh'
BeforeEach 'setup_brew_diff'
AfterEach 'cleanup_sandbox'

setup_brew_diff() {
  setup_sandbox
  install_dist_from_checkout
  mkdir -p "${SANDBOX}/mocks"
  cat >"${SANDBOX}/mocks/brew" <<'STUB'
#!/bin/sh
if [ "$1" = bundle ] && [ "$2" = dump ]; then
  for arg in "$@"; do
    case "${arg}" in
      --file=*) target="${arg#--file=}" ;;
    esac
  done
  printf 'brew "git"\n' >"${target}"
  exit 0
fi
if [ "$1" = bundle ] && [ "$2" = check ]; then
  if [ "${BREW_TEST_MISSING:-0}" = 1 ]; then
    echo 'missing package from Brewfile'
    exit 1
  fi
  exit 0
fi
if [ "$1" = bundle ] && [ "$2" = cleanup ]; then
  if [ "${BREW_TEST_EXTRAS:-0}" = 1 ]; then
    printf 'brew "unlisted"\n'
  fi
  exit 0
fi
if [ "$1" = leaves ]; then
  echo git
  exit 0
fi
exit 1
STUB
  chmod +x "${SANDBOX}/mocks/brew"
  export PATH="${SANDBOX}/mocks:${PATH}"
  return 0
}

It '--help prints usage and exits 0'
When run script "${HOME}/.rn-forge/bin/rnfmac" brew diff --help
The status should be success
The output should include 'usage: rnfmac brew diff'
End

It 'rejects an unrecognized flag'
When run script "${HOME}/.rn-forge/bin/rnfmac" brew diff --bogus
The status should eq 1
The error should include 'usage: rnfmac brew diff'
End

It '--write fails when the macsetup-config checkout is missing'
rm -rf "${HOME}/.rn-forge/macsetup/config"
When run script "${HOME}/.rn-forge/bin/rnfmac" brew diff --write
The status should eq 1
The output should include 'macsetup config checkout is missing'
End

It '--write updates the current host Brewfile in macsetup-config'
When run script "${HOME}/.rn-forge/bin/rnfmac" brew diff --write
The status should be success
The output should include 'Brewfile updated'
The contents of file "${HOME}/.rn-forge/macsetup/config/hosts/testhost/Brewfile" should include 'brew "git"'
End

It 'hides a healthy result by default'
When run script "${HOME}/.rn-forge/bin/rnfmac" brew diff
The status should be success
The output should not include 'no drift — installed packages match the Brewfile'
The output should include '1 ok, 0 warning, 0 drift, 0 error'
End

It '--all includes the healthy result'
When run script "${HOME}/.rn-forge/bin/rnfmac" brew diff --all
The status should be success
The output should include 'no drift — installed packages match the Brewfile'
End

It 'exits 2 and preserves brew detail in human output'
export BREW_TEST_MISSING=1
When run script "${HOME}/.rn-forge/bin/rnfmac" brew diff
The status should eq 2
The output should include 'missing package from Brewfile'
The output should include '0 ok, 0 warning, 1 drift, 0 error'
End

It 'suppresses brew output in JSON mode'
export BREW_TEST_MISSING=1
export BREW_TEST_EXTRAS=1
When run script "${HOME}/.rn-forge/bin/rnfmac" brew diff --json
The status should eq 2
The output should match pattern '{*'
The output should include '"group":"brew"'
The output should include '"check":"brewfile-missing"'
The output should include '"check":"brewfile-extra"'
The output should not include 'missing package from Brewfile'
The output should not include 'brew "unlisted"'
End

It 'suppresses brew output and appends records in raw mode'
export BREW_TEST_MISSING=1
export BREW_TEST_EXTRAS=1
export RNFMAC_REPORT_FORMAT=raw
export RNFMAC_REPORT_FILE="${SANDBOX}/report.records"
When run script "${HOME}/.rn-forge/bin/rnfmac" brew diff
The status should eq 2
The output should be blank
The contents of file "${RNFMAC_REPORT_FILE}" should include 'brewfile-missing'
The contents of file "${RNFMAC_REPORT_FILE}" should include 'brewfile-extra'
End
End
