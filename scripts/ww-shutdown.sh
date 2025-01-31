#!/bin/sh
# Usage: ww-shutdown.sh [node]...
# Possible improvement: Parallelize the script

[ "$(whoami)" = 'root' ] || \
	{ printf 'Root permission is needed!\n'; exit 1; }

if [ "$#" -gt 0 ]; then nodes="$*"
else nodes="$(wwctl node list --net | sed -E -n 's/^[[:blank:]]*([[:alnum:]\.]+)[[:blank:]]+.+$/\1/p')"; fi

for _node in ${nodes}; do
	node="$(printf '%s' "${_node}" | sed -E 's/(\.)/\\\1/g')" # escape special dot character
	ip_regex='[[:blank:]]+([0-9]{1,3}(\.[0-9]{1,3}){3})' # matching IP address
	_ip_addr="$(wwctl node list --net | sed -E -n 's/^[[:blank:]]*'"${node}"'[[:blank:]]+.+'"${ip_regex}${ip_regex}"'.+$/\1/p')"

	[ -n "${_ip_addr}" ] || { printf 'Unavailable node: %s\n' "${_node}"; continue; }

	ip_addr="$(printf '%s' "${_ip_addr}" | sed -E 's/(\.)/\\\1/g')" # escape special dot character

	if_name="$(wwctl ssh "${_node}" -- ip -br -4 addr show | sed -E -n 's/^[[:blank:]]*'"${node}"':[[:blank:]]+([[:alnum:]]+)[[:blank:]]+.+'"${ip_addr}"'.+$/\1/p')"

	# Enable wake-on-lan and shutdown
	wwctl ssh "${_node}" -- ethtool -s "${if_name}" wol g '&&' poweroff
done
