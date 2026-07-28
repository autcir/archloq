# .zshrc — base Catppuccin Mocha (loq dotfiles)
# Materiale base per stow: alias utili + integrazioni Catppuccin Mocha.
# Lo script 02-shell.sh gestisce i plugin (autosuggestions, syntax-highlighting)
# e l'init di starship; questo file fornisce le impostazioni portabili.
#
# Se hai già un ~/.oh-my-zsh, questo file NON lo sovrascrive automaticamente:
# lo script 02-shell.sh merge-only. Usalo come insieme di snippet raccomandati.

# --- History ---------------------------------------------------------------
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_VERIFY
setopt INC_APPEND_HISTORY

# --- Completion ------------------------------------------------------------
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*' list-dirs-first true

# --- Keybindings -----------------------------------------------------------
bindkey -e
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward

# --- Alias Catppuccin Mocha friendly ----------------------------------------
alias ls='ls --color=auto --group-directories-first'
alias ll='ls -lah --color=auto --group-directories-first'
alias la='ls -A --color=auto --group-directories-first'
alias grep='grep --color=auto'
alias diff='diff --color=auto'
alias ip='ip -color=auto'
# Eye-care: meno output aggressivo, più compatto
alias df='df -h'
alias free='free -h'
alias cat='bat --paging=never 2>/dev/null || cat'
# Fastfetch alias per mostrare il sistema Catppuccin Mocha
alias ff='fastfetch'

# --- Eye-care export: less blue light se wlsunset/gammastep non attivi ------
# Suggerimento: attiva wlsunset come client Wayland per ridurre blue light sera.
# export REDSHIFT_TEMP=3500  # placeholder; usa systemd --user per wlsunset

# --- Starship init (se installato) -----------------------------------------
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

# --- Fastfetch on first shell (Catppuccin Mocha splash) ----------------------
if command -v fastfetch >/dev/null 2>&1 && [ -z "$LOQ_FF_SHOWN" ]; then
  export LOQ_FF_SHOWN=1
  # Decommenta per mostrare fastfetch ad ogni shell nuova:
  # fastfetch
fi
