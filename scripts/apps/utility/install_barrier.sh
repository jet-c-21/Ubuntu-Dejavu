#!/bin/bash
# script_name: install_barrier.sh
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

create_barrier_ssl_certification() {
  mkdir -p ~/.local/share/barrier/SSL
  openssl req -x509 -nodes -newkey rsa:2048 \
    -keyout ~/.local/share/barrier/SSL/Barrier.pem \
    -out ~/.local/share/barrier/SSL/Barrier.pem \
    -days 365 \
    -subj "/CN=$(hostname)"
}

setup_barrier_autostart() {
  cl_print "[*INFO*] - Creating Barrier (server mode) autostart setup..."

  local autostart_dir="${HOME}/.config/autostart"
  local barrier_desktop_path="${autostart_dir}/barrier.desktop"

  # Ensure autostart directory exists
  mkdir -p "${autostart_dir}"

  # Create the barrier.desktop file directly
  cat <<EOF > "${barrier_desktop_path}"
[Desktop Entry]
Type=Application
Exec=/usr/bin/barrier
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name[en_US]=Barrier
Name=Barrier
Comment[en_US]=run barrier
Comment=run barrier
EOF

  # Set correct permissions
  chmod +x "${barrier_desktop_path}"

  # Validate setup
  if [[ -f "${barrier_desktop_path}" && -x "${barrier_desktop_path}" ]]; then
    cl_print "[*INFO*] - Barrier autostart setup successfully." "green"
  else
    cl_print "[*ERROR*] - Failed to set up Barrier autostart." "red"
  fi
}


install_barrier() {
  cl_print "[*INFO*] - Start installing Barrier ..." "magenta"

  unlock_sudo

  # Update package list
  sudo apt update

  # Install Barrier
  sudo apt install -y barrier

  cl_print "[*INFO*] - Barrier installed and systemd service created.\n" "green"
}

main() {
  install_barrier
  setup_barrier_autostart
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
