#!/bin/bash
# script name: install_qemu_vm_manager.sh
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
  local result
  result="$(use_sudo whoami)"
  cl_print "[*INFO*] - unlocked sudo for user: $result" "cyan"
}
# <<<<<<<<<<<<<<<<<<<<<<<<<<<<<< use and unlock sudo <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

main() {
  unlock_sudo

  cl_print "[*INFO*] - Installing QEMU, libvirt, and GUI tools..." "cyan"

  sudo apt update
  sudo apt install -y \
    qemu-system \
    libguestfs-tools \
    libvirt-clients \
    libvirt-daemon-system \
    bridge-utils \
    virt-manager \
    ovmf \
    swtpm

  local username
  username="$(whoami)"

  sudo usermod -a -G libvirt "$username"
  sudo usermod -a -G kvm "$username"
  sudo usermod -a -G input "$username"

  # Enable libvirtd.socket (preferred on Ubuntu 22.04+)
  sudo systemctl enable --now libvirtd.socket

  # Start and auto-enable default virtual network
  if ! sudo virsh net-info default &>/dev/null; then
    cl_print "[*INFO*] - Creating default libvirt network..." "yellow"
    sudo virsh net-define /usr/share/libvirt/networks/default.xml
  fi

  sudo virsh net-start default || true
  sudo virsh net-autostart default

  cl_print "[*INFO*] - Virtualization environment ready!" "green"
  cl_print "[*NOTE*] - Please reboot or log out and log back in for group changes to take effect." "yellow"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
