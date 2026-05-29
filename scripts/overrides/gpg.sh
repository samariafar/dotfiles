gpg() {
	if [[ "$1" == 'import' && -n "$2" && -n "$3" ]]; then
		command gpg --import "$2"
		command gpg --import "$3"
		KEY_ID=$(command gpg --with-colons --import-options show-only --import "$2" | awk -F: '/fpr/{print $10; exit}')
		echo -e "5\ny\n" | command gpg --command-fd 0 --expert --edit-key "$KEY_ID" trust
	elif [[ "$1" == 'export' ]]; then
		command gpg --export --armor --output gpg-public.key "$2"
		command gpg --export-secret-key --armor --output gpg-private.key "$2"
	else
		command gpg "$@"
	fi
}
