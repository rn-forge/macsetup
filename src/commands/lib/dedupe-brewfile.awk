# Regroups a `brew bundle dump` Brewfile under `## taps`/`## formulae`/`## casks`
# headers and drops `brew` lines whose formula isn't in $LEAVES (dependency-only
# formulae) — see brew/diff.sh's write_brewfile.
BEGIN {
  n = split(ENVIRON["LEAVES"], arr, "\n"); for (i = 1; i <= n; i++) requested[arr[i]] = 1
  header["tap"] = "## taps"; header["brew"] = "## formulae"; header["cask"] = "## casks"
}
/^#/ { pending = $0; next }
/^brew "/ {
  name = $0
  sub(/^brew "/, "", name)
  sub(/".*/, "", name)
  if (!(name in requested)) { pending = ""; next }
}
{
  if ($1 != last_type) {
    if (last_type != "") print ""
    if ($1 in header) print header[$1]
    last_type = $1
  }
  if (pending != "") print pending
  pending = ""
  print
}
