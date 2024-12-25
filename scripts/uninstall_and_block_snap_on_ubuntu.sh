#!/bin/bash
set -e


# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>> color print >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
# Define the colors
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

# Define the print function
cl_print() {
  local text=$1
  local color=$2

  # If the second argument is "dflt", print the text without color
  if [ "$color" == "dflt" ]; then
    echo -e "$text"
    return
  fi

  # If only one argument is provided, print in pink color
  if [ $# -eq 1 ]; then
    color="pink"
  fi

  # If the color is not defined, default to pink
  if [ -z "${COLORS[$color]}" ]; then
    color="pink"
  fi

  echo -e "${COLORS[$color]}${text}${COLOR_RESET}"
}
# <<<<<<<<<<<<<<<<<<<<<<<<<<<<<< color print <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>> ask user input sudo password >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
echo "[*INFO*] - Please enter your sudo password:"
read -s user_input_password

verify_password() {
  # Function to verify the sudo password
  local password=$1
  echo $password | sudo -S true 2>/dev/null
  return $?
}

# Verify the password and assign it to the global variable SUDO_PWD
SUDO_PASSWORD=""
if verify_password "$user_input_password"; then
  SUDO_PASSWORD=$user_input_password
#   echo "Password is correct. Assigned to SUDO_PASSWORD variable."
else
  echo "[*ERROR*] - Incorrect password." >&2
  exit 1
fi
# <<<<<<<<<<<<<<<<<<<<<<<<<<<<<< ask user input sudo password <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>> use and unlock sudo >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
use_sudo() {
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
  echo "[*INFO*] - unlock $result privilege"
}

# <<<<<<<<<<<<<<<<<<<<<<<<<<<<<< use and unlock sudo <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

purge_all_snap_apps() {
  cl_print "[*INFO*] - this function have not been implemented yet, for safety, please manually uninstall all snap apps."

  # Check if there are any Snap apps installed
  if snap list | grep -q -v "^Name"; then
    cl_print "[*WARN*] - some Snap apps are still installed. Please remove them manually."
    return 1  # Exit with code 1 to indicate Snap apps are present
  else
    cl_print "[*INFO*] - No Snap apps detected. great! :)" "green"
    return 0  # Exit with code 0 to indicate success
  fi
}

disable_snapd_service() {
  cl_print "[*INFO*] - disable snapd service ..."
  unlock_sudo
  sudo systemctl stop snapd
  sudo systemctl disable snapd
  sudo systemctl mask snapd
  cl_print "[*INFO*] snapd is disabled and masked."
}

purge_snapd() {
  cl_print "[*INFO*] - purge snapd ..."
  unlock_sudo
  sudo apt purge -y snapd
  sudo apt autoremove -y
  cl_print "[*INFO*] snapd is purged."
}

prevent_snapd_upgrade() {
  cl_print "[*INFO*] - prevent snapd from being upgraded ..."
  unlock_sudo
  sudo apt-mark hold snapd
  cl_print "[*INFO*] snapd is held from upgrade."
}

delete_snap_related_files() {
  cl_print "[*INFO*] - delete snapd related files ..."
  unlock_sudo
  sudo rm -rf ~/snap/
  sudo rm -rf ~/.config/snapd
  sudo rm -rf ~/.cache/snap
  sudo rm -rf /snap
  sudo rm -rf /var/snap
  sudo rm -rf /var/lib/snapd

  cl_print "[*INFO*] snapd related files are deleted."
}

create_nosnap_pref_for_apt() {
  cl_print "[*INFO*] - create nosnap preference for apt ..."

  # Define the file path
  local pref_file="/etc/apt/preferences.d/nosnap.pref"

#  # Check if the file already exists
#  if [[ -f "$pref_file" ]]; then
#    cl_print "[*INFO*] - The nosnap preference file already exists at $pref_file."
#    return 0
#  fi

  # Ensure we have sudo permissions
  unlock_sudo

  # Write the configuration to the file
  sudo bash -c "cat > $pref_file <<EOF
Package: snapd
Pin: release a=*
Pin-Priority: -10
EOF"

  # Verify if the file was created successfully
  if [[ -f "$pref_file" ]]; then
    cl_print "[*INFO*] - The nosnap preference file has been created successfully at $pref_file."
  else
    cl_print "[*ERROR*] - Failed to create the nosnap preference file."
    return 1
  fi

  sudo apt update
  cl_print "[*INFO*] - finish to create nosnap preference for apt."
}

install_gnome_software() {
  cl_print "[*INFO*] - install gnome-software ..."
  unlock_sudo
  sudo apt install -y gnome-software
  cl_print "[*INFO*] - gnome-software is installed."
}

main() {
  purge_all_snap_apps
  disable_snapd_service
  purge_snapd
  prevent_snapd_upgrade
  delete_snap_related_files
  create_nosnap_pref_for_apt
  install_gnome_software

  cl_print "[*INFO*] - All done. Snap is uninstalled and blocked on your system." "green"
}

main