# Edit a file via a temp copy, preserving permissions and only writing
# back if the contents actually changed.
rewrite() {
	local file_path="$1"

	if [[ -f "$file_path" ]]; then
		file_name=$(basename "$file_path")
		tmp_file=$(mktemp -t "XXXX-${file_name}")
		pre_edit_checksum=$(checksum "$tmp_file")
		file_mode=$(stat -c "%a" "$file_path")

		"${EDITOR:-nano}" "$tmp_file"
		post_edit_checksum=$(checksum "$tmp_file")

		if [[ "$pre_edit_checksum" != "$post_edit_checksum" ]]; then
			cp "$tmp_file" "$file_path"
			chmod "$file_mode" "$file_path"
		fi

		rm -f "$tmp_file"
	else
		"${EDITOR:-nano}" "$file_path"
	fi
}
