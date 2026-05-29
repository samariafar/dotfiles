# `quit` bypasses the override below if you want plain shell exit while
# inside tmux without killing the session.
quit() {
	command exit
}

exit() {
	if [[ -n "$TMUX" ]]; then
		tmux kill-session
	else
		command exit
	fi
}
