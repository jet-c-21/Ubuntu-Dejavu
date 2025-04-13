#!/bin/bash
# shell name: apply_personal_gsettings.sh

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
  echo "[*INFO*] - unlock $result privilege"
}
# <<<<<<<<<<<<<<<<<<<<<<<<<<<<<< use and unlock sudo <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

change_appearance_color_to_dark_and_purple() {
  cl_print "[*INFO*] - Applying dark theme and Ubuntu magenta accent color..." "cyan"

  gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
  gsettings set org.gnome.desktop.interface gtk-theme 'Yaru-magenta-dark'
  gsettings set org.gnome.desktop.interface icon-theme 'Yaru-magenta-dark'

  cl_print "[*INFO*] - Appearance set to dark mode with Ubuntu magenta accent. \n" "cyan"
}


handle_dash_to_dock_to_be_installed() {
  cl_print "[*INFO*] - Checking Dash-to-Dock status..." "cyan"

  local EXT_ID="dash-to-dock@micxgx.gmail.com"
  local EXT_PATH="$HOME/.local/share/gnome-shell/extensions/$EXT_ID"

  # Disable built-in Ubuntu Dock
  if gnome-extensions list | grep -q "ubuntu-dock@ubuntu.com"; then
    cl_print "[*INFO*] - Disabling default Ubuntu Dock..." "yellow"
    gnome-extensions disable ubuntu-dock@ubuntu.com
  fi

  # Check if dash-to-dock is already installed
  if gnome-extensions list | grep -q "$EXT_ID"; then
    cl_print "[*INFO*] - Dash-to-Dock is already installed." "green"
    return
  fi

  # Install prerequisites
  unlock_sudo
  sudo apt install -y unzip wget

  # Download latest zip from GNOME Extensions
  local TMP_DIR="/tmp/dash-to-dock-install"
  mkdir -p "$TMP_DIR"
  local ZIP_URL="https://extensions.gnome.org/extension-data/dash-to-dockmicxgx.gmail.com.v81.shell-extension.zip"
  local ZIP_FILE="$TMP_DIR/dash-to-dock.zip"

  cl_print "[*INFO*] - Downloading Dash-to-Dock extension..." "cyan"
  wget -O "$ZIP_FILE" "$ZIP_URL"

  cl_print "[*INFO*] - Installing Dash-to-Dock to local extensions folder..." "cyan"
  mkdir -p "$EXT_PATH"
  unzip -q "$ZIP_FILE" -d "$EXT_PATH"

  # Enable the extension
  gnome-extensions enable "$EXT_ID"

  cl_print "[*INFO*] - Dash-to-Dock has been installed and enabled." "green"
}





change_dock_to_macos_style() {
  cl_print "[*INFO*] - Changing dock to macOS style..." "cyan"

  # Set the dock to be floating (not fixed)
  gsettings set org.gnome.shell.extensions.dash-to-dock dock-fixed false

  # Disable panel mode (extend-height)
  cl_print "[*INFO*] - Disabling panel mode (compact dock)..." "cyan"
  gsettings set org.gnome.shell.extensions.dash-to-dock extend-height false

  # Move dock to the bottom
  cl_print "[*INFO*] - Moving dock to the bottom..." "cyan"
  gsettings set org.gnome.shell.extensions.dash-to-dock dock-position 'BOTTOM'

  # Enable 'Show Apps at Top'
  cl_print "[*INFO*] - Enabling 'Show Apps at Top'..." "cyan"
  gsettings set org.gnome.shell.extensions.dash-to-dock show-apps-at-top true

  # show docks on all displays
  cl_print "[*INFO*] - Showing docks on all displays..." "cyan"
  gsettings set org.gnome.shell.extensions.dash-to-dock show-dock-on-all-displays true

  cl_print "[*INFO*] - Dock successfully changed to macOS style." "green"
}

enable_auto_hide_dock() {
  local setting="org.gnome.shell.extensions.dash-to-dock dock-fixed"
  local value="false"
  gsettings set ${setting} ${value}

  cl_print "[*INFO*] - Enabling auto-hide dock \n" "cyan"
}

# Change click action for Dash-to-Dock
change_click_window_to_minimize_to_dock() {
  local setting="org.gnome.shell.extensions.dash-to-dock click-action"
  local value="'minimize'"
  cl_print "[*INFO*] - Changing click action to minimize to dock \n" "cyan"
  gsettings set ${setting} ${value}
}

enable_window_hover_show() {
  # Enable window preview on hover
  gsettings set org.gnome.shell.extensions.dash-to-dock window-preview 'true'
  
  cl_print "[*INFO*] - Window hover preview enabled! \n" "green"
}

disable_recent_file_history() {
  gsettings set org.gnome.desktop.privacy remember-recent-files false
  gsettings set org.gnome.desktop.applications.recency false
  cl_print "[*INFO*] - Recent file history disabled! \n" "green"
}

hide_home_dir_on_desktop() {
  # Hide the home directory on the desktop
  gsettings set org.gnome.desktop.background show-desktop-icons false
  cl_print "[*INFO*] - Home directory hidden on desktop! \n" "green"
}

hide_mount_drive_on_dock() {
  # Hide the mount drive on the dock
  gsettings set org.gnome.shell.extensions.dash-to-dock show-mounts false
  cl_print "[*INFO*] - Mount drive hidden on dock! \n" "green"
}

optimize_search_settings() {
  cl_print "[*INFO*] - Optimizing GNOME search to only include Calculator and Settings..." "cyan"

  # Enable only Calculator and Settings
  gsettings set org.gnome.desktop.search-providers disabled \
    "['org.gnome.Characters.desktop', 'org.gnome.clocks.desktop', 'org.gnome.Nautilus.desktop', 'gnome-terminal.desktop', 'org.gnome.seahorse.Application.desktop']"

  cl_print "[*INFO*] - GNOME search results now limited to Calculator and Settings." "green"
}


main() {
   change_appearance_color_to_dark_and_purple
   check_dash_to_dock_is_installed

   sleep 600

   change_dock_to_macos_style
   enable_auto_hide_dock
   change_click_window_to_minimize_to_dock
   enable_window_hover_show
   disable_recent_file_history
   hide_home_dir_on_desktop
   hide_mount_drive_on_dock

   cl_print "[*INFO*] - All personal gsettings applied successfully! \n" "green"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
