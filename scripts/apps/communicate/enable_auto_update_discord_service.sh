#!/bin/bash
# script name: enable_auto_update_discord_service.sh
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


# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>> unlock sudo once >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
unlock_sudo() {
  local command="whoami"
  local result="$(echo "$SUDO_PASSWORD" | sudo -SE "$command")"
  echo "[*INFO*] - unlocked $result privilege"
}
# <<<<<<<<<<<<<<<<<<<<<<<<<<<<<< unlock sudo once <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

main() {
  unlock_sudo

  local this_script_path="$(realpath "$0")"
  local this_script_parent_dir="$(dirname "$this_script_path")"
  local src_script_to_run="${this_script_parent_dir}/auto_update_discord.sh"
  local service_file_path="/etc/systemd/system/auto-update-discord.service"
  local script_to_run="/usr/local/bin/auto_update_discord.sh"
  local log_path="/var/log/auto_update_discord.log"

  # >>> Copy script to system path if needed
  cl_print "[*INFO*] - Copying updater script to $script_to_run" "cyan"
  sudo cp "$src_script_to_run" "$script_to_run"
  sudo chmod +x "$script_to_run"

  # >>> Create systemd service using safe method
  cl_print "[*INFO*] - Creating systemd service at $service_file_path" "cyan"

  sudo tee "$service_file_path" > /dev/null <<EOF
[Unit]
Description=Auto update Discord on reboot
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/auto_update_discord.sh
StandardOutput=append:/var/log/auto_update_discord.log
StandardError=append:/var/log/auto_update_discord.log
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reload
  sudo systemctl enable auto-update-discord.service

  cl_print "[*DONE*] - Service enabled! Will auto-update Discord on reboot." "green"
  cl_print "[*INFO*] - Output will be logged to: $log_path" "green"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
