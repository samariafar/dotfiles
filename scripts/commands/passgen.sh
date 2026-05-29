passgen() {
	local lower='abcdefghijklmnopqrstuvwxyz'
	local upper='ABCDEFGHIJKLMNOPQRSTUVWXYZ'
	local digits='0123456789'
	local specials='-_=+.,:'

	rand_range() {
		local min=$1
		local max=$2
		echo $(( min + $(od -An -N2 -tu2 /dev/urandom) % (max - min + 1) ))
	}

	gen_chars() {
		local charset=$1
		local count=$2
		tr -dc -- "$charset" < /dev/urandom | head -c $count
	}

	local num_count=$(rand_range 4 6)
	local spec_count=$(rand_range 4 6)
	local remaining=$((24 - num_count - spec_count))

	local lower_count upper_count
	if (( remaining <= 12 )); then
		local max_lower=$((remaining < 6 ? remaining : 6))
		lower_count=$(rand_range 0 $max_lower)
		upper_count=$((remaining - lower_count))
	else
		lower_count=$((remaining / 2))
		upper_count=$((remaining - lower_count))
	fi

	local password=""
	password+=$(gen_chars "$lower" $lower_count)
	password+=$(gen_chars "$upper" $upper_count)
	password+=$(gen_chars "$digits" $num_count)
	password+=$(gen_chars "$specials" $spec_count)

	echo "$password" | fold -w1 | shuf --random-source=/dev/urandom | tr -d '\n'
	echo
}
