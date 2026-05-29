# shellcheck shell=bash
#
# `git` subcommand overrides. Adds custom subcommands (last, log, profile,
# unstage, untrack) and modifies a few defaults (filemode off on init/clone,
# `git commit "msg"` shorthand). Sourced from bashrc.
#
# Profile data is sourced from ~/.config/git/profiles.sh, which inlines the
# Sam profile and conditionally layers the artifex profile from the sops-
# rendered env file at ~/.config/git/profiles.d/artifex.env.

[[ -f ~/.config/git/profiles.sh ]] && source ~/.config/git/profiles.sh

# Emoji-decorated log helper used by `git log` and `git last`.
# Signature (%G?): G good, B bad, U unknown, X/Y/R expired/revoked, E uncheckable, N none.
# Author (%ae): mapped to a per-profile emoji from PROFILE_EMOJI.
# Unknown authors get a generic 👤 marker.
__git_emoji_log() {
	local fmt='~~%ae~~@@%G?@@%C(auto)%h%d%Creset %s'
	local emoji_sed='
		s/@@G@@/🔏 /g
		s/@@N@@//g
		s/@@[BXYR]@@/❗ /g
		s/@@[UE]@@/❓ /g
	'
	local profile email_escaped
	for profile in "${VALID_PROFILES[@]}"; do
		email_escaped="${PROFILE_EMAIL[$profile]//./\\.}"
		emoji_sed+=$'\n'"s|~~${email_escaped}~~|${PROFILE_EMOJI[$profile]} |g"
	done
	emoji_sed+=$'\n''s/~~[^~]*~~/👤 /g'

	if [[ -t 1 ]]; then
		command git log --color=always --pretty=tformat:"$fmt" "$@" \
			| sed "$emoji_sed" \
			| less -FRX
	else
		command git log --pretty=tformat:"$fmt" "$@" \
			| sed "$emoji_sed"
	fi
}

__git_profile_show_current() {
	local name="" email="" source=""
	if [[ -d .git ]]; then
		name=$(command git config --local user.name 2>/dev/null || true)
		email=$(command git config --local user.email 2>/dev/null || true)
		if [[ -z "$email" ]]; then
			name=$(command git config --global user.name 2>/dev/null || true)
			email=$(command git config --global user.email 2>/dev/null || true)
			source=" (global)"
		fi
	else
		name=$(command git config user.name 2>/dev/null || true)
		email=$(command git config user.email 2>/dev/null || true)
	fi
	if [[ -n "$email" ]]; then
		gum style --foreground 212 "$name <$email>$source"
	else
		gum style --foreground 244 "No profile set."
	fi
}

__git_profile_apply() {
	local target="$1"
	if [[ -z "${PROFILE_NAME[$target]:-}" ]]; then
		echo "Error: invalid profile '$target' (valid: ${VALID_PROFILES[*]})" >&2
		return 1
	fi
	local old_name old_email
	old_name=$(command git config user.name 2>/dev/null || true)
	old_email=$(command git config user.email 2>/dev/null || true)
	if [[ -n "$old_email" ]]; then
		gum style --foreground 244 "Replacing $old_name <$old_email>"
	fi
	command git config user.name "${PROFILE_NAME[$target]}"
	command git config user.email "${PROFILE_EMAIL[$target]}"
	command git config user.signingkey "${PROFILE_SIGNINGKEY[$target]}"
	command git config core.sshCommand "ssh -i ${PROFILE_SSHKEY[$target]}"
	gum style --foreground 212 "Switched to ${PROFILE_NAME[$target]} <${PROFILE_EMAIL[$target]}>"
}

__git_profile_do_init() {
	local default name
	default=$(basename "$PWD")
	name=$(gum input --header "Project name" --value "$default") || return 1
	[[ -z "$name" ]] && name="$default"
	git init -q  # routes through the override above → also sets core.filemode=false
	printf '# %s\n\n' "$name" > README.md
	command git add README.md
	git commit "Initial commit"  # routes through the commit override (no -m needed)
	gum style --foreground 212 "Initialized repo for '$name'"
}

__git_profile_pick_and_apply() {
	local choice
	choice=$(gum choose --header "Pick a profile:" "${VALID_PROFILES[@]}") || return 1
	__git_profile_apply "$choice"
}

__git_profile_handle_no_args() {
	if [[ -d .git ]]; then
		__git_profile_show_current
		return
	fi
	if command git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
		local toplevel
		toplevel=$(command git rev-parse --show-toplevel)
		if gum confirm "Inside existing repo at '$toplevel'. Initialize a nested repo here anyway?"; then
			__git_profile_do_init || return 0
			__git_profile_pick_and_apply
		else
			__git_profile_show_current
		fi
	else
		if gum confirm "Not a git repo. Initialize here?"; then
			__git_profile_do_init || return 0
			__git_profile_pick_and_apply
		else
			gum style --foreground 244 "Aborted — no repo to set a profile on."
		fi
	fi
}

__git_profile_handle_use() {
	local target="$1"
	if [[ -z "${PROFILE_NAME[$target]:-}" ]]; then
		echo "Error: invalid profile '$target' (valid: ${VALID_PROFILES[*]})" >&2
		return 1
	fi
	if [[ -d .git ]]; then
		__git_profile_apply "$target"
		return
	fi
	if command git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
		local toplevel
		toplevel=$(command git rev-parse --show-toplevel)
		if gum confirm "Inside existing repo at '$toplevel'. Initialize a nested repo here anyway?"; then
			__git_profile_do_init || return 0
		fi
		__git_profile_apply "$target"
	else
		if gum confirm "Not a git repo. Initialize here?"; then
			__git_profile_do_init || return 0
			__git_profile_apply "$target"
		else
			gum style --foreground 244 "Aborted."
		fi
	fi
}

git() {
	local subcmd="${1:-}"
	case "$subcmd" in
		init)
			command git "$@"
			command git config --local core.filemode false
			;;
		clone)
			local repo_url="${2:-}"
			local dest_dir="${3:-}"
			command git "$@"
			local dir
			if [[ -n "$dest_dir" ]]; then
				dir="$dest_dir"
			else
				dir="${repo_url##*/}"
				dir="${dir%.git}"
			fi
			command git -C "$dir" config --local core.filemode false
			;;
		commit)
			# `git commit "msg"` shorthand — drops the `-m`. Signing is already
			# enforced by commit.gpgsign=true in git config.
			local message="${2:-}"
			if [[ -n "$message" && ! "$message" =~ ^-.* ]]; then
				command git commit --message "$message"
			else
				command git "$@"
			fi
			;;
		log)
			local extra_args=("${@:2}")
			__git_emoji_log --graph --decorate --all "${extra_args[@]}"
			;;
		last)
			__git_emoji_log -1 --decorate HEAD
			;;
		unstage)
			local paths=("${@:2}")
			command git reset HEAD -- "${paths[@]}"
			;;
		untrack)
			local paths=("${@:2}")
			command git rm --cached -- "${paths[@]}"
			;;
		profile)
			local action="${2:-}"
			local profile_name="${3:-}"
			case "$action" in
				"")
					__git_profile_handle_no_args
					;;
				use)
					if [[ -z "$profile_name" ]]; then
						local valid="${VALID_PROFILES[*]}"
						echo "Usage: git profile [use <${valid// /|}>]" >&2
						return 1
					fi
					__git_profile_handle_use "$profile_name"
					;;
				*)
					local valid="${VALID_PROFILES[*]}"
					echo "Usage: git profile [use <${valid// /|}>]" >&2
					return 1
					;;
			esac
			;;
		*)
			command git "$@"
			;;
	esac
}
