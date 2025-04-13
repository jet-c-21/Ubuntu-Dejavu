#!/bin/bash
# script name: uninstall_and_block_snap_on_ubuntu.sh
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
# Define a global SUDO_PASSWORD if not already set
if [[ -z "${SUDO_PASSWORD}" ]]; then
    echo -n "[*INFO*] - Please enter your sudo password: "
    read -s user_input_password
    echo

    verify_password() {
        local password=$1
        echo "$password" | sudo -S -v &>/dev/null
        return $?
    }

    if verify_password "$user_input_password"; then
        export SUDO_PASSWORD="$user_input_password"
        # You may also refresh the timestamp so future sudo doesn't ask again
        echo "$SUDO_PASSWORD" | sudo -S -v &>/dev/null
    else
        echo "[*ERROR*] - Incorrect password." >&2
        exit 1
    fi
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

_purge_all_snap_apps_on_ubuntu_nobel_numbat() {
  cl_print "[*INFO*] - Start purging default Snap apps on Ubuntu 24.04 Noble Numbat..."

  unlock_sudo

  # Helper: Wait for auto-refresh to finish
  _wait_for_snap_auto_refresh() {
    while snap changes | grep -q "Doing.*auto-refresh"; do
      cl_print "[*INFO*] - Waiting for ongoing snap auto-refresh to finish..." "yellow"
      sleep 5
    done
  }

  # List of snaps to remove in the proper order
  local snaps_to_remove=(
    "firefox"
    "thunderbird"
    "snap-store"
    "firmware-updater"
    "canonical-livepatch"
    "snapd-desktop-integration"
    "gtk-common-themes"
    "gnome-42-2204"
    "core22"
    "bare"
  )

  for snap in "${snaps_to_remove[@]}"; do
    if snap list | grep -q "^$snap\b"; then
      cl_print "[*INFO*] - Preparing to remove $snap ..."
      _wait_for_snap_auto_refresh

      local attempt=1
      local max_attempts=3

      while (( attempt <= max_attempts )); do
        if sudo snap remove --purge "$snap"; then
          cl_print "[*INFO*] - $snap removed successfully." "green"
          break
        else
          cl_print "[*WARN*] - Failed to remove $snap (attempt $attempt). Retrying in 5s..." "yellow"
          _wait_for_snap_auto_refresh
          sleep 5
        fi
        ((attempt++))
      done

      if (( attempt > max_attempts )); then
        cl_print "[*ERROR*] - Failed to remove $snap after $max_attempts attempts." "red"
      fi
    else
      cl_print "[*INFO*] - $snap is not installed, skipping." "yellow"
    fi
  done

  cl_print "[*INFO*] - Snap app purge process finished." "green"
}

purge_all_snap_apps() {
  _purge_all_snap_apps_on_ubuntu_nobel_numbat

  # Check how many Snap packages are installed (excluding the header line)
  # in normal case snap list should be empty or only contain snapd
  local snap_count
  snap_count=$(snap list | awk 'NR>1 {print $1}' | grep -v '^snapd$' | wc -l)

  if [[ "$snap_count" -eq 0 ]]; then
    cl_print "[*INFO*] - No Snap apps detected. great! :) \n" "green"
    return 0
  else
    cl_print "[*WARN*] - Some Snap apps are still installed (excluding snapd). Please remove them manually. \n" "red"
    return 1
  fi
}


disable_snapd_service() {
  cl_print "[*INFO*] - disable snapd service ..."
  unlock_sudo
  sudo systemctl stop snapd
  sudo systemctl disable snapd
  sudo systemctl mask snapd
  cl_print "[*INFO*] snapd is disabled and masked. \n" "green"
}

purge_snapd() {
  cl_print "[*INFO*] - purge snapd ..."
  unlock_sudo
  sudo apt purge -y snapd
  sudo apt autoremove -y
  cl_print "[*INFO*] snapd is purged. \n" "green"
}

prevent_snapd_upgrade() {
  cl_print "[*INFO*] - prevent snapd from being upgraded ..."
  unlock_sudo
  sudo apt-mark hold snapd
  cl_print "[*INFO*] snapd is held from upgrade. \n" "green"
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

  cl_print "[*INFO*] snapd related files are deleted. \n" "green"
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
  cl_print "[*INFO*] - finish to create nosnap preference for apt. \n" "green"
}

install_gnome_software() {
  cl_print "[*INFO*] - install gnome-software ..."
  unlock_sudo
  sudo apt install -y gnome-software
  cl_print "[*INFO*] - gnome-software is installed. \n" "green"
}

install_gdebi() {
  cl_print "[*INFO*] - install gdebi ..." "cyan"
  unlock_sudo
  sudo apt install -y gdebi-core gdebi

  cl_print "[*INFO*] - gdebi is installed." "green"

  # Optional: Set gdebi as the default app for .deb files
  if command -v xdg-mime &>/dev/null; then
    cl_print "[*INFO*] - setting gdebi-gtk as default handler for .deb files ..." "cyan"
    xdg-mime default gdebi.desktop application/vnd.debian.binary-package
    cl_print "[*INFO*] - gdebi-gtk is now the default for .deb files. \n" "green"
  else
    cl_print "[*WARN*] - xdg-mime not found. Cannot set file association." "yellow"
  fi
}

main() {
  if ! command -v snap &>/dev/null; then
    cl_print "[*INFO*] - Snap is not installed on this system. Nothing to uninstall. \n" "green"
    return 0
  fi

  purge_all_snap_apps
  disable_snapd_service
  purge_snapd
  prevent_snapd_upgrade
  delete_snap_related_files
  create_nosnap_pref_for_apt
  install_gnome_software
  install_gdebi

  cl_print "[*INFO*] - All done. Snap is uninstalled and blocked on your system. \n" "green"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi