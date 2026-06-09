# shellcheck shell=bash
# shellcheck disable=SC2154 # Variables like $dim defined in lib/colors.sh

if ! git config --global user.name &>/dev/null; then
	echo -e "${bold}Git identity not configured. Setting up...${reset}"
	echo -n "Enter your full name for git commits: "
	read -r git_name </dev/tty
	echo -n "Enter your email for git commits: "
	read -r git_email </dev/tty
	git config --global user.name "$git_name"
	git config --global user.email "$git_email"
	info "Git identity configured"
else
	info "Git identity already configured"
fi
