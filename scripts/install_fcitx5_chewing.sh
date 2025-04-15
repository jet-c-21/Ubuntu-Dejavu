#!/bin/bash
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
use_sudo() {
  local cmd="echo ${SUDO_PASSWORD} | sudo -SE "
  for param in "$@"; do
    cmd+="${param} "
  done
  eval "${cmd}"
}

unlock_sudo() {
  local result="$(use_sudo whoami)"
  cl_print "[*INFO*] - unlocked sudo for user: $result" "cyan"
}
# <<<<<<<<<<<<<<<<<<<<<<<<<<<<<< use and unlock sudo <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

prompt_reboot_notification() {
  local reboot_countdown_sec=10
  local zenity_title="Fcitx5 Chewing Installer"

  if command -v zenity &>/dev/null; then
    (
      {
        for ((i=0; i<=reboot_countdown_sec; i++)); do
          echo "$((i * 100 / reboot_countdown_sec))"
          echo "# Rebooting in $((reboot_countdown_sec - i)) second(s)..."
          sleep 1
        done
      } | zenity --progress \
           --title="${zenity_title}" \
           --text="Preparing to reboot..." \
           --percentage=0 \
           --auto-close \
           --no-cancel 2>/dev/null || {
             cl_print "[*WARN*] - Zenity failed to display. Falling back to terminal countdown." "yellow"
             sleep "$reboot_countdown_sec"
           }

      unlock_sudo
      sudo reboot
    ) &
  else
    cl_print "[*WARN*] - 'zenity' not installed. Falling back to silent countdown." "yellow"
    sleep "$reboot_countdown_sec"
    unlock_sudo
    sudo reboot
  fi
}


main() {
  unlock_sudo

  sudo apt purge fcitx*
  sudo apt install -y fcitx5 fcitx5-chinese-addons fcitx5-chewing

  cl_print "[*INFO*] - please click yes, and select fcitx5 as input method" "cyan"
  im-config

  prompt_reboot_notification
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
