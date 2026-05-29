function clear {
	command clear

	if [[ -n "$TMUX" ]]; then
		tmux clear-history
	fi
}
