#!/bin/bash
# Builds the macsetup distribution into dist/:
#   dist/macsetup/                 staged dist tree (= tarball contents):
#                                   src/ contents plus VERSION
#   dist/macsetup.tar.gz         release tarball — unversioned name,
#                                          so install.sh/upgrade.sh can fetch
#                                          it via GitHub's releases/latest/
#                                          download/<name> alias without an
#                                          api.github.com lookup; the version
#                                          lives in VERSION inside it.
#   dist/macsetup.tar.gz.sha256  checksum sidecar, verified by
#                                          install.sh/upgrade.sh when present
#   dist/install.sh                       loose installer entry point release asset

set -eu

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAGE="${REPO_ROOT}/dist/macsetup"
TARBALL="${REPO_ROOT}/dist/macsetup.tar.gz"

# Prints the sha256 of $1 — sha256sum on Linux, shasum on macOS.
sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

rm -rf "${STAGE}"
mkdir -p "${STAGE}"

# Stage the dist tree: full src/ contents plus VERSION.
cp -R "${REPO_ROOT}/src/." "${STAGE}/"
find "${STAGE}" -name '.DS_Store' -delete
cp -f "${REPO_ROOT}/VERSION" "${STAGE}/VERSION"

# Executable bits — dispatcher, installer, and every command script.
chmod +x "${STAGE}/rnfmac.sh" "${STAGE}/install.sh"
find "${STAGE}/commands" -name '*.sh' -exec chmod +x {} +

# Release assets: tarball of the staged tree, its checksum, + loose install.sh for direct curl.
tar -czf "${TARBALL}" -C "${STAGE}" .
sha256_of "${TARBALL}" >"${TARBALL}.sha256"
cp -f "${REPO_ROOT}/src/install.sh" "${REPO_ROOT}/dist/install.sh"

printf 'Staged:   %s\n' "${STAGE}"
printf 'Tarball:  %s\n' "${TARBALL}"
printf 'Checksum: %s\n' "${TARBALL}.sha256"
printf 'Install:  %s\n' "${REPO_ROOT}/dist/install.sh"
