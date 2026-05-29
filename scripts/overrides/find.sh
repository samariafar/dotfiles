find() {
	command find "$@" 2>&1 | grep -v 'Permission denied'
}
