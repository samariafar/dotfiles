# ~/.profile — login-shell environment.
#
# Sourced by login shells (GDM session, ssh, console login). Variables exported
# here are inherited by all child processes including the GNOME session
# manager. ~/.bashrc is sourced from this file when running bash.

# --- environment --------------------------------------------------------------

export DIRENV_LOG_FORMAT=""
export EDITOR=nano
export HISTTIMEFORMAT="[%F %T]  "
export SOPS_AGE_KEY_FILE="${HOME}/Vault/Keys/Sam/age-private.key"
export VISUAL=nano

# --- PATH ---------------------------------------------------------------------

# Local-user binaries (~/.local/bin) — used by the shell category to shim the
# Ubuntu-renamed CLIs (batcat → bat, fdfind → fd).
if [[ -d "$HOME/.local/bin" && ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
	PATH="$HOME/.local/bin:$PATH"
fi

# Volta (Node toolchain manager). Populated by the dev-tooling category later.
if [[ -d "$HOME/.volta" ]]; then
	export VOLTA_HOME="$HOME/.volta"
	[[ ":$PATH:" != *":$VOLTA_HOME/bin:"* ]] && PATH="$VOLTA_HOME/bin:$PATH"
fi

export PATH

# --- bash entry point ---------------------------------------------------------

# When invoked via bash, source the interactive rc so login shells get the
# same aliases / commands / overrides as non-login interactive shells.
if [[ -n "${BASH_VERSION:-}" && -f "$HOME/.bashrc" ]]; then
	. "$HOME/.bashrc"
fi
