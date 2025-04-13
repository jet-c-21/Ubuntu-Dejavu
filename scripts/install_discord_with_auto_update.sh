#!/bin/bash
# script name: install_discord_with_auto_update.sh
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


# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>> ask user input sudo password >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
if [[ -z "${SUDO_PASSWORD}" ]]; then
  echo -n "[*INFO*] - Please enter your sudo password: "
  read -s user_input_password
  echo
  verify_password() {
    echo "$1" | sudo -S -v &>/dev/null
  }
  if verify_password "$user_input_password"; then
    export SUDO_PASSWORD="$user_input_password"
    echo "$SUDO_PASSWORD" | sudo -S -v &>/dev/null
  else
    echo "[*ERROR*] - Incorrect password." >&2
    exit 1
  fi
fi
# <<<<<<<<<<<<<<<<<<<<<<<<<<<<<< ask user input sudo password <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>> use and unlock sudo >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
use_sudo() { # it is a sudo experiment wrapper function, for most case please just use unlock_sudo
  : <<COMMENT
straight way:
  echo "$SUDO_PASSWORD" | sudo -S your command
example:
  echo "$SUDO_PASSWORD" | sudo -S apt-get update
COMMENT

  local cmd="echo ${SUDO_PASSWORD} | sudo -SE "
  for param in "$@"; do
    cmd+="${param} "
  done
  eval "${cmd}"
}

unlock_sudo() {
  local command="whoami"
  local result="$(use_sudo "$command")"
  echo "[*INFO*] - unlocked $result privilege"
}
# <<<<<<<<<<<<<<<<<<<<<<<<<<<<<< use and unlock sudo <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


install_discord_apt() {
  # GitHub repo: https://github.com/palfrey/discord-apt
  # ref: https://tevps.net/blog/2023/09/03/apt-repository-for-discord/
  
  cl_print "[*INFO*] - Installing Discord via discord-apt ..."

  unlock_sudo

  # Add the Discord APT repository
  cl_print "[*INFO*] - Adding Discord APT repository..."
  sudo sh -c 'echo "deb https://palfrey.github.io/discord-apt/debian/ ./" > /etc/apt/sources.list.d/discord.list'

  # Download the GPG key for the repository
  cl_print "[*INFO*] - Adding the GPG key for the repository..."
  wget -qO - https://palfrey.github.io/discord-apt/discord-apt.gpg.asc | sudo tee /etc/apt/trusted.gpg.d/discord-apt.gpg.asc

  # Update package lists
  sudo apt update

  # Install Discord
  sudo apt install -y discord

  cl_print "[*INFO*] - Discord installed successfully via APT." "green"
}

enable_discord_auto_update() {
  cl_print "[*INFO*] - Enabling auto-updates for Discord ..."

  # Define the cron job to run on reboot
  local cron_job="@reboot /usr/bin/apt-get update && /usr/bin/apt-get install -y discord"

  # Check if the cron job already exists
  if ! crontab -l | grep -F "$cron_job" > /dev/null 2>&1; then
    # If it doesn't exist, add it to the root user's crontab
    cl_print "[*INFO*] - Creating cron job to auto-update Discord on boot..."
    unlock_sudo
    sudo sh -c "(crontab -l; echo \"$cron_job\") | crontab -"
    cl_print "[*INFO*] - Auto-updates for Discord enabled successfully." "green"
  else
    cl_print "[*INFO*] - Cron job for Discord auto-update already exists, skipping." "yellow"
  fi
}

main() {
  install_discord_apt
  enable_discord_auto_update
  
  cl_print "[*INFO*] - Installation and auto-update setup completed." "green"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
