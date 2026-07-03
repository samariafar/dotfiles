# shellcheck shell=bash
#
# sshx - SSH connection helper driven by ~/Projects/Personal/dotfiles/secrets.yaml.
#
# Usage:  sshx <nickname>          # or: use the per-nickname alias generated at load time
#         sshx                     # gum picker over known nicknames
#
# Server declarations live entirely in secrets.yaml under `servers.<nickname>.*`.
# Recognised fields per entry:
#
#   host         required   hostname or IP
#   port         default 22 SSH port
#   user         default root
#   password                Login password. Presence with a value = auto; presence
#                           with an empty value = prompt via gum on connect;
#                           absence = server doesn't ask (key-only auth).
#   totp_secret             Base32 TOTP seed. Same three-state semantics as
#                           password: value auto-generates a code via oathtool,
#                           empty triggers gum prompt for the 6-digit code,
#                           absence means the server doesn't ask.
#   jump                    Nickname of another entry to use as ProxyJump.
#
# On shell startup, this file:
#   1. Compares mtime of secrets.yaml with a cache of nicknames at
#      ~/.cache/sshx/aliases.sh.
#   2. If cache is stale (or missing), does one `sops -d` + `yq` to extract
#      nicknames and rewrites the cache.
#   3. Sources the cache to register `alias <nickname>="sshx <nickname>"`.
#
# Net cost: one sops decrypt per secrets.yaml edit, then free until next edit.

SSHX_SECRETS_YAML="$HOME/Projects/Personal/dotfiles/secrets.yaml"

# Cache-aware alias registration. Runs at source time (bashrc load).
__sshx_refresh_aliases() {
	local cache="$HOME/.cache/sshx/aliases.sh"

	if [[ ! -r "$SSHX_SECRETS_YAML" ]]; then
		return 0
	fi

	if [[ ! -f "$cache" ]] || [[ "$SSHX_SECRETS_YAML" -nt "$cache" ]]; then
		mkdir -p "$(dirname "$cache")"
		local tmp names
		tmp=$(mktemp "${cache}.XXXXXX") || return 0
		chmod 600 "$tmp"
		names=$(sops -d "$SSHX_SECRETS_YAML" 2>/dev/null \
			| yq -r '.servers // {} | keys[]' 2>/dev/null) || true
		while IFS= read -r n; do
			[[ -z "$n" ]] && continue
			printf 'alias %q="sshx %s"\n' "$n" "$n" >> "$tmp"
		done <<<"$names"
		mv "$tmp" "$cache"
	fi

	# shellcheck disable=SC1090
	source "$cache"
}
__sshx_refresh_aliases

sshx() {
	if [[ ! -r "$SSHX_SECRETS_YAML" ]]; then
		gum style --foreground 196 "sshx: $SSHX_SECRETS_YAML not readable"
		return 1
	fi

	local yaml
	if ! yaml=$(sops -d "$SSHX_SECRETS_YAML" 2>/dev/null); then
		gum style --foreground 196 "sshx: sops decryption failed for $SSHX_SECRETS_YAML"
		return 1
	fi

	local server="${1:-}"
	if [[ -z "$server" ]]; then
		local names
		names=$(yq -r '.servers // {} | keys[]' <<<"$yaml")
		if [[ -z "$names" ]]; then
			gum style --foreground 196 "sshx: no servers declared under \`servers:\` in $SSHX_SECRETS_YAML"
			return 1
		fi
		server=$(printf '%s\n' "$names" | sort | gum choose --header "Server:") || return 1
	fi

	local exists
	exists=$(yq -r ".servers | has(\"$server\")" <<<"$yaml")
	if [[ "$exists" != "true" ]]; then
		gum style --foreground 196 "sshx: unknown server '$server'"
		gum style --foreground 244 "known: $(yq -r '.servers | keys | join(", ")' <<<"$yaml")"
		return 1
	fi

	local host port user jump
	host=$(yq -r ".servers.\"$server\".host // \"\"" <<<"$yaml")
	port=$(yq -r ".servers.\"$server\".port // \"22\"" <<<"$yaml")
	user=$(yq -r ".servers.\"$server\".user // \"root\"" <<<"$yaml")
	jump=$(yq -r ".servers.\"$server\".jump // \"\"" <<<"$yaml")

	if [[ -z "$host" ]]; then
		gum style --foreground 196 "sshx: no host for '$server' — set servers.$server.host in $SSHX_SECRETS_YAML"
		return 1
	fi

	local key="$HOME/Vault/Keys/Sam/ssh-private.key"
	local target="${user}@${host}"

	mkdir -p "$XDG_RUNTIME_DIR/sshx"
	chmod 700 "$XDG_RUNTIME_DIR/sshx"

	local -a ssh_opts=(
		-p "$port"
		-i "$key"
		-o "ControlMaster=auto"
		-o "ControlPath=$XDG_RUNTIME_DIR/sshx/%r@%h:%p"
		-o "ControlPersist=10m"
	)

	if [[ -n "$jump" ]]; then
		local jexists
		jexists=$(yq -r ".servers | has(\"$jump\")" <<<"$yaml")
		if [[ "$jexists" != "true" ]]; then
			gum style --foreground 196 "sshx: '$server' references unknown jump '$jump'"
			return 1
		fi
		local jhost jport juser
		jhost=$(yq -r ".servers.\"$jump\".host" <<<"$yaml")
		jport=$(yq -r ".servers.\"$jump\".port // \"22\"" <<<"$yaml")
		juser=$(yq -r ".servers.\"$jump\".user // \"root\"" <<<"$yaml")
		ssh_opts+=( -o "ProxyJump=${juser}@${jhost}:${jport}" )
	fi

	local attempt
	for attempt in 1 2; do
		local preflight
		preflight=$(ssh "${ssh_opts[@]}" \
			-o BatchMode=yes \
			-o ConnectTimeout=5 \
			-o PasswordAuthentication=no \
			-o KbdInteractiveAuthentication=no \
			"$target" true 2>&1)
		local pre_rc=$?

		if [[ $pre_rc -eq 0 ]]; then
			exec ssh "${ssh_opts[@]}" "$target"
		fi

		if grep -qE 'Host key verification failed|REMOTE HOST IDENTIFICATION HAS CHANGED' <<<"$preflight"; then
			if (( attempt == 1 )) && gum confirm "Host key mismatch in chain. Remove entries for [$host]:$port$([[ -n "$jump" ]] && printf ' + [%s]:%s' "$jhost" "$jport") from known_hosts and retry?"; then
				ssh-keygen -R "[$host]:$port" >/dev/null 2>&1
				ssh-keygen -R "$host" >/dev/null 2>&1
				if [[ -n "$jump" ]]; then
					ssh-keygen -R "[$jhost]:$jport" >/dev/null 2>&1
					ssh-keygen -R "$jhost" >/dev/null 2>&1
				fi
				continue
			fi
			gum style --foreground 196 "sshx: aborted."
			return 1
		fi

		# Password / TOTP path. Build ordered lists — jump first, then target
		# — because ssh authenticates hops in that order and expect consumes
		# them in the same sequence. For each hop:
		#   - `password` key present with value  → use it silently
		#   - `password` key present, empty      → prompt via gum
		#   - `password` key absent              → skip (no password step)
		# Same three-state semantics for `totp_secret`.
		local -a chain=()
		if [[ -n "$jump" ]]; then chain+=("$jump"); fi
		chain+=("$server")

		local -a passwords=() totps=()
		local hop hop_host hop_user hop_has_pw hop_pw_val hop_has_seed hop_seed hop_pw hop_totp
		for hop in "${chain[@]}"; do
			hop_host=$(yq -r ".servers.\"$hop\".host" <<<"$yaml")
			hop_user=$(yq -r ".servers.\"$hop\".user // \"root\"" <<<"$yaml")
			hop_has_pw=$(yq -r ".servers.\"$hop\" | has(\"password\")" <<<"$yaml")
			hop_pw_val=$(yq -r ".servers.\"$hop\".password // \"\"" <<<"$yaml")
			hop_has_seed=$(yq -r ".servers.\"$hop\" | has(\"totp_secret\")" <<<"$yaml")
			hop_seed=$(yq -r ".servers.\"$hop\".totp_secret // \"\"" <<<"$yaml")

			if [[ "$hop_has_pw" == "true" ]]; then
				if [[ -n "$hop_pw_val" ]]; then
					hop_pw="$hop_pw_val"
				else
					hop_pw=$(gum input --password --header "Password for ${hop_user}@${hop_host}") || return 1
				fi
				passwords+=("$hop_pw")
			fi

			if [[ "$hop_has_seed" == "true" ]]; then
				if [[ -n "$hop_seed" ]]; then
					hop_totp=$(oathtool --totp -b "$hop_seed") || {
						gum style --foreground 196 "sshx: oathtool failed for '$hop'"
						return 1
					}
				else
					hop_totp=$(gum input --header "TOTP for ${hop_user}@${hop_host}" --placeholder "6-digit code") || return 1
				fi
				totps+=("$hop_totp")
			fi
		done
		unset yaml

		SSHX_PASSWORDS=$(printf '%s\n' "${passwords[@]}") \
		SSHX_TOTPS=$(printf '%s\n' "${totps[@]}") \
		SSHX_SPAWN_ARGS=$(printf '%s\n' ssh "${ssh_opts[@]}" "$target") \
			_sshx_expect
		return $?
	done
}

# expect driver. Consumes chain-ordered credential lists (jump first, then
# target). As each auth prompt fires we pop from the matching queue (TOTPs
# for `Verification code:`, passwords for anything matching `password:`).
# Order within a hop doesn't matter; interact fires only when BOTH queues are
# exhausted, so a password-first PAM stack (or any other ordering) still gets
# fully answered before handing control to the user.
_sshx_expect() {
	expect <<'EXPECT'
set timeout -1
set passwords [split $env(SSHX_PASSWORDS) "\n"]
set totps     [split $env(SSHX_TOTPS) "\n"]
set argv      [split $env(SSHX_SPAWN_ARGS) "\n"]

foreach var {passwords totps argv} {
    if {[lindex [set $var] end] eq ""} {
        set $var [lrange [set $var] 0 end-1]
    }
}

set pwd_idx  0
set totp_idx 0
set n_pwds   [llength $passwords]
set n_totps  [llength $totps]

proc done_or_continue {} {
    global pwd_idx totp_idx n_pwds n_totps
    if {$pwd_idx >= $n_pwds && $totp_idx >= $n_totps} {
        interact
    } else {
        exp_continue
    }
}

eval spawn -noecho $argv

expect {
    "Host key verification failed"           { exit 42 }
    "REMOTE HOST IDENTIFICATION HAS CHANGED" { exit 42 }
    "Verification code:" {
        if {$totp_idx >= $n_totps} {
            send_user "sshx: unexpected extra TOTP prompt (missing servers.<name>.totp_secret for a hop?)\n"
            exit 3
        }
        send -- "[lindex $totps $totp_idx]\r"
        incr totp_idx
        done_or_continue
    }
    -re "(?i)password:" {
        if {$pwd_idx >= $n_pwds} {
            send_user "sshx: unexpected extra password prompt\n"
            exit 3
        }
        send -- "[lindex $passwords $pwd_idx]\r"
        incr pwd_idx
        done_or_continue
    }
    eof { exit 4 }
}
EXPECT
}
