# shellcheck shell=bash
#
# Colored logging primitives. Source from any script:
#   source "${DOTFILES_ROOT}/scripts/lib/log.sh"
#
# All messages go to stderr so stdout stays reserved for actual program output.

# Resolve colors once. Use tput when stderr is a tty; otherwise empty strings so
# logs stay readable when piped or redirected to a file.
if [[ -t 2 ]] && command -v tput >/dev/null 2>&1; then
	_LOG_RESET=$(tput sgr0)
	_LOG_BOLD=$(tput bold)
	_LOG_DIM=$(tput dim)
	_LOG_RED=$(tput setaf 1)
	_LOG_GREEN=$(tput setaf 2)
	_LOG_YELLOW=$(tput setaf 3)
	_LOG_BLUE=$(tput setaf 4)
	_LOG_CYAN=$(tput setaf 6)
else
	_LOG_RESET=
	_LOG_BOLD=
	_LOG_DIM=
	_LOG_RED=
	_LOG_GREEN=
	_LOG_YELLOW=
	_LOG_BLUE=
	_LOG_CYAN=
fi

log_step()    { printf '%s==>%s %s%s%s\n'    "${_LOG_BLUE}"   "${_LOG_RESET}" "${_LOG_BOLD}" "$*" "${_LOG_RESET}" >&2; }
log_info()    { printf '%s -- %s %s\n'       "${_LOG_CYAN}"   "${_LOG_RESET}" "$*" >&2; }
log_success() { printf '%s ok %s %s\n'       "${_LOG_GREEN}"  "${_LOG_RESET}" "$*" >&2; }
log_warn()    { printf '%s ww %s %s\n'       "${_LOG_YELLOW}" "${_LOG_RESET}" "$*" >&2; }
log_error()   { printf '%s !! %s %s\n'       "${_LOG_RED}"    "${_LOG_RESET}" "$*" >&2; }
log_debug()   { [[ ${DEBUG:-} == true ]] && printf '%s .. %s %s\n' "${_LOG_DIM}" "${_LOG_RESET}" "$*" >&2 || true; }

# Fatal error: log and exit non-zero.
die() {
	log_error "$@"
	exit 1
}
