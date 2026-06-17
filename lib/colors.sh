# shellcheck shell=bash
# Terminal color and output helpers - sourced by run.sh and other scripts
# shellcheck disable=SC2034  # Variables are used by sourcing scripts

reset='\033[0m'
bold='\033[1m'
dim='\033[38;5;245m'
blue='\033[94m'
coral='\033[38;5;209m'
green='\033[92m'
magenta='\033[95m'
red='\033[31m'
sky='\033[38;5;117m'
white='\033[97m'
yellow='\033[33m'

# Output helpers — keep formatting out of step files
info() { echo -e "${dim}· $1${reset}"; }
action() { echo -e "${sky}› $1${reset}"; }
warn() { echo -e "${yellow}⚠ $1${reset}"; }
success() { echo -e "${green}✓ $1${reset}"; }
prompt() { echo -ne "${bold}$1${reset} "; }
