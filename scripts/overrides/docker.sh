docker() {
	if [[ "$1" == 'compose' && "$2" == 'down' && "$3" == '-v' && -n "$4" ]]; then
		# `docker compose down -v <svc>` does not work on a single service;
		# stop + rm achieves the equivalent for one service.
		docker compose stop "$4"
		docker compose rm -f "$4"
	elif [[ "$1" == 'cleanup' ]]; then
		command docker system prune --all --force
	else
		command docker "$@"
	fi
}
