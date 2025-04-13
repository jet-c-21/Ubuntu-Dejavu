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
  local extension_id="dash-to-dock@micxgx.gmail.com"
  local extension_path="$HOME/.local/share/gnome-shell/extensions/$extension_id"
  local zip_file="/tmp/dash-to-dock.zip"
  local extension_url="https://extensions.gnome.org/extension-data/${extension_id}.shell-extension.zip"

  cl_print "[*INFO*] - Checking if Dash-to-Dock is already installed..." "cyan"

  if [[ -d "$extension_path" ]]; then
    cl_print "[*INFO*] - Dash-to-Dock already exists in $extension_path." "green"
    return 0
  fi

  cl_print "[*INFO*] - Downloading Dash-to-Dock from GNOME Extensions..." "cyan"
  curl -sSL -o "$zip_file" "$extension_url"

  if [[ ! -f "$zip_file" ]] || ! unzip -t "$zip_file" &>/dev/null; then
    cl_print "[*ERROR*] - Failed to download or validate Dash-to-Dock zip." "red"
    return 1
  fi

  cl_print "[*INFO*] - Installing Dash-to-Dock to local extensions folder..." "cyan"
  mkdir -p "$extension_path"
  unzip -o -q "$zip_file" -d "$extension_path"

  if [[ -f "$extension_path/metadata.json" ]]; then
    cl_print "[*INFO*] - Dash-to-Dock installed successfully at $extension_path." "green"
  else
    cl_print "[*ERROR*] - Dash-to-Dock installation failed." "red"
    return 1
  fi
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
   handle_dash_to_dock_to_be_installed

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
