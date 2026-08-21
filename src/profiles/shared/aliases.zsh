# shellcheck disable=SC2148
## rnf aliases
rnfdev() {
  if [ -z "$1" ]; then
    cd "${HOME}/devel/workspaces/rn-forge" || return
  else
    cd "${HOME}/devel/workspaces/rn-forge/$1" || return
  fi
}

## brew aliases
alias brl="brew list"
alias bru="brew upgrade"
alias bri="brew install"
alias brs="brew search"
alias brc="brew cleanup"
alias brf="brew info"
alias bra="brew info --cask --json=v2 \$(brew ls --cask) | jq -r '.casks[]|select(.auto_updates==true)|.token'"

## claude aliases
alias claude-trust='jq ".projects[\"$(pwd)\"].hasTrustDialogAccepted = true" ${HOME}/.claude.json > ${HOME}/.claude.json.tmp && mv ${HOME}/.claude.json.tmp ${HOME}/.claude.json'
alias claude-remote='claude remote-control --name "$(basename "$(pwd)")" --remote-control-session-name-prefix "$(basename "$(pwd)")-" --permission-mode auto --spawn same-dir '

## claude aliases
alias codex-trust='KEY="$(pwd)" VALUE="trusted" yq -i -p toml -o toml ".projects[strenv(KEY)].trust_level = strenv(VALUE)" ${HOME}/.codex/config.toml'
