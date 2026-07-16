# shellcheck disable=SC2148
[ -n "${RNFMAC_PROFILE_LOADED:-}" ] && log_warning "macsetup profile loaded" && return
RNFMAC_PROFILE_LOADED=1

echo "loading macsetup profile"

#################### rn-forge home
export RNF_HOME="${HOME}/.rn-forge"
export PATH="${RNF_HOME}/bin:${PATH}"

#################### shkit
source "${RNF_HOME}/shkit/current/shkit.sh"

#################### homebrew
if [ "$(uname -m)" = "arm64" ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  eval "$(/usr/local/bin/brew shellenv zsh)"
fi

## homebrew flags
export HOMEBREW_NO_ASK=1
export HOMEBREW_UPGRADE_GREEDY=1

## homebrew REMOTE_RELAY flags
export HOMEBREW_REMOTE_RELAY_ENABLED=0
export HOMEBREW_REMOTE_RELAY_HOST="rohitnarayanan@rohitmacmini.local"
export HOMEBREW_REMOTE_RELAY_DEBUG=1

#################### oh-my-zsh
export ZSH_THEME="rohitnarayanan"
fpath+=${RNF_HOME}/completions
fpath+=${ZSH_CUSTOM}/plugins/zsh-completions/src
autoload -Uz compinit && compinit
export plugins=(git zsh-autosuggestions zsh-syntax-highlighting uv nvm sdk)

#################### uv
if command -v uv >/dev/null 2>&1; then
  eval "$(uv generate-shell-completion zsh)"
  eval "$(uvx --generate-shell-completion zsh)"
fi
export PATH="${HOME}/.local/bin:${PATH}"

#################### nvm
if [ -d "${HOME}/.nvm" ]; then
  export NVM_DIR="$HOME/.nvm"
  source "$NVM_DIR/nvm.sh"
fi

#################### sdkman
if [ -d "${HOME}/.sdkman" ]; then
  export SDKMAN_DIR="${HOME}/.sdkman"
  source "${SDKMAN_DIR}/bin/sdkman-init.sh"
fi

#printf "========== rn-forge: PATH ==========\n\033[1;33m%s\033[0m\n" "${PATH}"
