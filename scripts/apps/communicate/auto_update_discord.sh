#!/bin/bash
# script name: auto_update_discord.sh
# version: 1.0.1
set -e

# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>> color print >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
declare -A COLORS=(
  ["red"]='\e[1;31m'
  ["green"]='\e[1;32m'
  ["blue"]='\e[1;34m'
  ["yellow"]='\e[1;33m'
  ["magenta"]='\e[1;35m'
  ["cyan"]='\e[1;36m'
  ["pink"]='\e[1;38;5;206m'
  ["white"]='\e[1;37m'
)
COLOR_RESET='\e[0m'

cl_print() {
  local text=$1
  local color=$2
  if [ "$color" == "dflt" ]; then
    echo -e "$text"
    return
  fi
  if [ $# -eq 1 ] || [ -z "${COLORS[$color]}" ]; then
    color="pink"
  fi
  echo -e "${COLORS[$color]}${text}${COLOR_RESET}"
}
# <<<<<<<<<<<<<<<<<<<<<<<<<<<<<< color print <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

get_pretty_datetime_str() {
  local datetime_str
  datetime_str=$(date '+%Y-%m-%d %H:%M:%S')
  echo "$datetime_str"
}

execute_user_is_root() {
  if [[ $EUID -ne 0 ]]; then
    cl_print "[*ERROR*] - $(get_pretty_datetime_str) - This script must be run as root." "red"
    exit 1
  fi
}

wait_until_can_access_discord_site() {
  local max_attempts=10
  local attempt=0
  local sleep_time=1

  while ! (curl -s "https://discord.com" &>/dev/null || true); do
    if (( attempt >= max_attempts )); then
      cl_print "[*ERROR*] - $(get_pretty_datetime_str) - Unable to access Discord site after $max_attempts attempts." "red"
      exit 1
    fi
    cl_print "[*INFO*] - $(get_pretty_datetime_str) - Waiting for Discord site to be accessible... (Attempt $((attempt + 1))/$max_attempts)" "yellow"
    sleep "$sleep_time"
    ((attempt++))
  done

  cl_print "[*INFO*] - $(get_pretty_datetime_str) - Discord site is accessible." "green"
}

get_installed_discord_version() {
  dpkg-query -W -f='${Version}' discord 2>/dev/null || echo "not_installed"
}

get_latest_discord_version() {
  local attempt=0 max_attempts=5
  local final_url=""
  local version=""

  while [[ $attempt -lt $max_attempts ]]; do
    final_url=$(curl -s -L -o /dev/null -w '%{url_effective}' "https://discord.com/api/download/stable?platform=linux&format=deb" || true)
    if [[ -n "$final_url" ]]; then
      version=$(echo "$final_url" | grep -oP 'discord[-_]?\K[0-9.]+' | sed 's/\.$//')
      if [[ -n "$version" ]]; then
        echo "$version"
        return 0
      fi
    fi
    cl_print "[*WARN*] - $(get_pretty_datetime_str) - Failed to extract version (Attempt $((attempt + 1))/$max_attempts)..." "yellow"
    sleep 2
    ((attempt++))
  done

  cl_print "[*ERROR*] - $(get_pretty_datetime_str) - Failed to fetch latest Discord version." "red"
  return 1
}

download_and_install_discord() {
  local version="$1"
  local deb_file="/tmp/discord_${version}.deb"

  cl_print "[*INFO*] - $(get_pretty_datetime_str) - Downloading Discord $version ..." "cyan"
  if ! wget -4 -O "$deb_file" "https://discord.com/api/download/stable?platform=linux&format=deb"; then
    cl_print "[*ERROR*] - $(get_pretty_datetime_str) - Failed to download Discord package." "red"
    exit 1
  fi

  cl_print "[*INFO*] - $(get_pretty_datetime_str) - Installing Discord $version ..." "green"
  dpkg -i "$deb_file"
}

main() {
  wait_until_can_access_discord_site
  local installed_version=$(get_installed_discord_version)
  local latest_version=$(get_latest_discord_version)

  cl_print "[*INFO*] - $(get_pretty_datetime_str) - Installed Discord version: $installed_version"
  cl_print "[*INFO*] - $(get_pretty_datetime_str) - Latest Discord version: $latest_version"

  if [[ "$installed_version" == "$latest_version" ]]; then
    cl_print "[*INFO*] - $(get_pretty_datetime_str) - Discord is already up to date :)" "green"
  else
    cl_print "[*INFO*] - $(get_pretty_datetime_str) - Updating Discord from $installed_version to $latest_version" "yellow"
    download_and_install_discord "$latest_version"
    cl_print "[*DONE*] - $(get_pretty_datetime_str) - Discord has been updated to $latest_version" "green"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  execute_user_is_root
  main "$@"
fi

# add get_pretty_datetime_str in very log line