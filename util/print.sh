#!/bin/bash
# * Bash 3.2 (2007)

# Print optional str $2 as bold green text
# Print str $1 on new line as normal green text
# Finally print time
print_green() {
	local GREEN='\033[0;32m'
	local BOLD_GREEN='\033[1;32m'
	local NO_COLOR='\033[0m'
	if (($# >= 2)); then
		local now
		now=$(date)
		printf "Time: %s" "$now"
		echo -e "\n${BOLD_GREEN}$2${NO_COLOR}"
	fi
	echo -e "${GREEN}$1${NO_COLOR}"
}
