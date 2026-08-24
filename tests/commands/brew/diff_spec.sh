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
if [ "$1" = leaves ]; then
  echo git
  exit 0
fi
exit 1
STUB
  chmod +x "${SANDBOX}/mocks/brew"
  export PATH="${SANDBOX}/mocks:${PATH}"
}

It '--write updates the current host Brewfile in macsetup-config'
When run script "${HOME}/.rn-forge/bin/rnfmac" brew diff --write
The status should be success
The output should include 'Brewfile updated'
The contents of file "${HOME}/.rn-forge/macsetup/config/hosts/testhost/Brewfile" should include 'brew "git"'
End
End
