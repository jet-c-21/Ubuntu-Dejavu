#!/bin/bash
# script_name: install_x_screen_saver.sh
# version: 1.0.0
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



setup_x_screensaver_autostart() {
  cl_print "[*INFO*] - Creating X Screen Saver autostart ..."

  local autostart_dir="${HOME}/.config/autostart"
  local install_x_screen_saver_desktop_path="${autostart_dir}/xscreensaver.desktop"

  # Ensure autostart directory exists
  mkdir -p "${autostart_dir}"

  # Create the xscreensaver.desktop file
  cat <<EOF > "${install_x_screen_saver_desktop_path}"
[Desktop Entry]
Type=Application
Exec=xscreensaver -no-splash
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=xscreensaver
Comment=Start xscreensaver daemon
EOF

  # Set correct permissions
  chmod +x "${install_x_screen_saver_desktop_path}"

  # Validate setup
  if [[ -f "${install_x_screen_saver_desktop_path}" ]] && \
     grep -q "Exec=xscreensaver -no-splash" "${install_x_screen_saver_desktop_path}" && \
     grep -q "X-GNOME-Autostart-enabled=true" "${install_x_screen_saver_desktop_path}"; then
    cl_print "[*SUCCESS*] - X Screen Saver autostart setup completed and validated. \n" "green"
  else
    cl_print "[*ERROR*] - Failed to properly create X Screen Saver autostart setup." "red"
  fi
}


install_x_screen_saver() {
  cl_print "[*INFO*] - Start installing X Screen Saver ..."

  unlock_sudo

  sudo apt-get install -y xscreensaver xscreensaver-gl-extra xscreensaver-data-extra mpv

  cl_print "[*INFO*] - X Screen Saver installed successfully. \n" "green"
}

main() {
  install_x_screen_saver
  setup_x_screensaver_autostart
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
