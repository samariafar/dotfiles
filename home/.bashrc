# ~/.bashrc — interactive non-login shell config.
#
# Sourced by interactive non-login bash shells. The login-shell entry point is
# ~/.profile, which sources this file when running under bash. Replaces
# Ubuntu's default ~/.bashrc wholesale.

# Bail out for non-interactive shells (scp, rsync, etc. break otherwise).
[[ $- != *i* ]] && return

# --- shell options ------------------------------------------------------------

shopt -s \
	checkjobs \
	checkwinsize \
	cmdhist \
	dotglob \
	extglob \
	globstar \
	histappend \
	lithist \
	nocaseglob

# --- history ------------------------------------------------------------------

HISTSIZE=10000
HISTFILESIZE=100000
HISTCONTROL=ignoreboth
HISTIGNORE='clear:exit:history:htop:man:tmux:zellij'
HISTTIMEFORMAT='[%F %T]  '

# --- aliases ------------------------------------------------------------------

alias ..='cd ..'
alias artisan='php artisan'
alias clipboard='wl-copy'
alias con='warp-cli connect'
alias dis='warp-cli disconnect'
alias dockers="docker ps --format 'table {{ .ID }}\t{{.Names}}\t{{.Status}}'"
alias hog='ncdu /'
alias htop='htop -t'
alias ll='eza -lah --git --time-style=long-iso --group-directories-first'
alias ls='eza'
alias open='xdg-open'
alias python='python3'
alias sail='./vendor/bin/sail'
alias tree="eza --tree -lah --git --time-style=long-iso --ignore-glob='.git|node_modules'"
alias zed='zeditor'

# --- environment & PATH -------------------------------------------------------

# Re-source ~/.profile so any env changes (e.g. via dotfiles re-apply) reach
# interactive non-login shells without a logout/login cycle.
[[ -f "$HOME/.profile" ]] && . "$HOME/.profile"

# --- bash completion (apt: bash-completion) -----------------------------------

if ! shopt -oq posix; then
	if [[ -f /usr/share/bash-completion/bash_completion ]]; then
		. /usr/share/bash-completion/bash_completion
	elif [[ -f /etc/bash_completion ]]; then
		. /etc/bash_completion
	fi
fi

# --- custom commands & overrides ---------------------------------------------

# Linked from scripts/{commands,overrides}/ into these dirs by the `shell`
# category install script. Iterating over the symlinked directory keeps the
# load order deterministic (glob expansion is alphabetical).
for script in "$HOME"/.config/bash/commands/*.sh; do
	[[ -f "$script" ]] && . "$script"
done
for script in "$HOME"/.config/bash/overrides/*.sh; do
	[[ -f "$script" ]] && . "$script"
done

# --- shell-integration hooks --------------------------------------------------

if command -v zoxide >/dev/null 2>&1; then
	eval "$(zoxide init bash)"
fi

if command -v direnv >/dev/null 2>&1; then
	eval "$(direnv hook bash)"
fi

# --- prompt: starship --------------------------------------------------------

if command -v starship >/dev/null 2>&1; then
	eval "$(starship init bash)"
fi

# --- prompt command ----------------------------------------------------------

# Newline-preserver (zsh PROMPT_SP equivalent) + cross-session history sync.
# When previous output lacks a trailing \n, prints an inverse-video % marker and
# forces the prompt onto a fresh line; invisible otherwise.
PROMPT_COMMAND='printf "\033[7m%%\033[0m%*s\r\033[K" "$((COLUMNS-1))" ""; history -a; history -n'
