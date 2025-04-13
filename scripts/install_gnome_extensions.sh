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


install_tophat() {
  # url: https://extensions.gnome.org/extension/5219/tophat/
  local ext_id="5219"
  local ext_uuid="TopHat@seenaburns.github.io"

  cl_print "[*INFO*] - Installing TopHat (ID: $ext_id, UUID: $ext_uuid)..." "green"

  # Start install in background
  gext install "$ext_id" &

  # Wait for the GUI prompt to appear (you can tweak the sleep)
  sleep 2

  # Check if using X11 (Wayland doesn't support xdotool)
  if [ "$XDG_SESSION_TYPE" = "x11" ]; then
    cl_print "[*INFO*] - Attempting to auto-click 'Install' using xdotool..." "blue"
    # Activate the 'Install Extension' dialog and press Enter
    xdotool search --name "Install Extension" windowactivate --sync key Return
  else
    cl_print "[*WARN*] - You are not on X11. xdotool cannot auto-click the install dialog on Wayland." "yellow"
    cl_print "Please manually click 'Install' in the popup dialog." "yellow"
  fi

  # Wait a moment for install to complete
  sleep 3

  # Enable the extension
  gext enable "$ext_uuid" || {
    cl_print "[*ERROR*] - Failed to enable $ext_uuid" "red"
    return 1
  }

  cl_print "[*DONE*] - TopHat extension installed and enabled successfully." "green"
}


main() {
  install_tophat
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
