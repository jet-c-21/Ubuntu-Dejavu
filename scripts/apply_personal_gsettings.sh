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

  cl_print "[*INFO*] - Checking if Dash-to-Dock is already installed..." "cyan"
  if [[ -d "$extension_path" ]]; then
    cl_print "[*INFO*] - Dash-to-Dock already exists at $extension_path." "green"
    return 0
  fi

  unlock_sudo
  sudo apt install -y curl unzip jq

  cl_print "[*INFO*] - Fetching Dash-to-Dock download URL via GNOME API..." "cyan"
  local api_url="https://extensions.gnome.org/extension-info/?uuid=${extension_id}&shell_version=$(gnome-shell --version | grep -oP '\d+\.\d+')"
  local download_url
  download_url=$(curl -s "$api_url" | jq -r '.download_url')

  if [[ -z "$download_url" || "$download_url" == "null" ]]; then
    cl_print "[*ERROR*] - Failed to find valid Dash-to-Dock download URL." "red"
    return 1
  fi

  local full_url="https://extensions.gnome.org${download_url}"
  cl_print "[*INFO*] - Downloading from: $full_url" "cyan"
  curl -sSL -o "$zip_file" "$full_url"

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

  gsettings set org.gnome.shell.extensions.dash-to-dock dock-fixed false
  gsettings set org.gnome.shell.extensions.dash-to-dock extend-height false
  gsettings set org.gnome.shell.extensions.dash-to-dock dock-position 'BOTTOM'
  # gsettings set org.gnome.shell.extensions.dash-to-dock dock-position 'LEFT'
  gsettings set org.gnome.shell.extensions.dash-to-dock show-apps-at-top true
  gsettings set org.gnome.shell.extensions.dash-to-dock icon-size-fixed false
  gsettings set org.gnome.shell.extensions.dash-to-dock multi-monitor true

  cl_print "[*INFO*] - Dock successfully changed to macOS style." "green"
}

enable_auto_hide_dock() {
  gsettings set org.gnome.shell.extensions.dash-to-dock intellihide true
  cl_print "[*INFO*] - Enabling auto-hide dock \n" "cyan"
}

# Change click action for Dash-to-Dock
change_click_window_action() {
  # gsettings set org.gnome.shell.extensions.dash-to-dock click-action 'minimize'

  gsettings set org.gnome.shell.extensions.dash-to-dock click-action 'minimize-or-previews'
  cl_print "[*INFO*] - Changing click action to minimize or previews \n" "cyan"
}

change_scroll_action() {
  gsettings set org.gnome.shell.extensions.dash-to-dock scroll-action 'cycle-windows'
  cl_print "[*INFO*] - Changing scroll action to cycle windows \n" "cyan"
}

enable_window_hover_show() {
  # Enable window preview on hover
  gsettings set org.gnome.shell.extensions.dash-to-dock show-windows-preview true
  
  cl_print "[*INFO*] - Window hover preview enabled! \n" "green"
}

change_dock_background_opacity() {
  local opacity="${1:-0.5}"  # Default to 0.5 if no argument passed

  # Change dock background opacity
  gsettings set org.gnome.shell.extensions.dash-to-dock background-opacity "$opacity"
  cl_print "[*INFO*] - Dock background opacity set to $opacity! \n" "green"
}


disable_recent_file_history() {
  gsettings set org.gnome.desktop.privacy remember-recent-files false
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

hide_trashcan_on_dock() {
  # Hide the trashcan on the dock
  gsettings set org.gnome.shell.extensions.dash-to-dock show-trash false
  cl_print "[*INFO*] - Trashcan hidden on dock! \n" "green"
}

disable_dash_to_dock_overview_on_startup() {
  # Disable Dash-to-Dock overview on startup
  gsettings set org.gnome.shell.extensions.dash-to-dock disable-overview-on-startup true
  cl_print "[*INFO*] - Dash-to-Dock overview disabled on startup! \n" "green"
}

optimize_search_settings() {
  cl_print "[*INFO*] - Optimizing GNOME search to only include Calculator and Settings..." "cyan"

  local allowed=(
    "gnome-calculator.desktop"
    "gnome-control-center.desktop"
  )

  local disabled=(
    "org.gnome.Nautilus.desktop"
    "org.gnome.clocks.desktop"
    "org.gnome.Characters.desktop"
    "org.gnome.seahorse.Application.desktop"
    "org.gnome.Calendar.desktop"
    "gnome-terminal.desktop"
    "org.gnome.Weather.Application.desktop"
    "org.gnome.Software.desktop"
    "org.gnome.Terminal.desktop"
  )

  # Convert arrays to valid gsettings string lists
  local allowed_str disabled_str
  allowed_str=$(printf "'%s', " "${allowed[@]}" | sed 's/, $//')
  disabled_str=$(printf "'%s', " "${disabled[@]}" | sed 's/, $//')

  gsettings set org.gnome.desktop.search-providers enabled "[$allowed_str]"
  gsettings set org.gnome.desktop.search-providers disabled "[$disabled_str]"
  gsettings set org.gnome.desktop.search-providers sort-order "[$allowed_str]"

  cl_print "[*INFO*] - GNOME search results now limited to Calculator and Settings." "green"
}

remove_default_app_from_dock() {
  cl_print "[*INFO*] - Removing default apps from dock..." "blue"

  apps_to_remove=(
    "yelp.desktop"
    "libreoffice-writer.desktop"
    "org.gnome.Rhythmbox3.desktop"
  )

  local current_apps
  current_apps=$(gsettings get org.gnome.shell favorite-apps)

  for app in "${apps_to_remove[@]}"; do
    if [[ "$current_apps" == *"'$app'"* || "$current_apps" == *"\"$app\""* ]]; then
      cl_print "[*INFO*] - Removing '$app' from dock..." "yellow"
      current_apps=$(echo "$current_apps" | sed "s/'$app',\?//g" | sed 's/,,/,/g' | sed 's/\[,\{0,1\}\]/[]/g')
    else
      cl_print "[*INFO*] - '$app' not found in dock. Skipping." "cyan"
    fi
  done

  # Replace single with double quotes for valid GVariant syntax
  current_apps="${current_apps//\'/\"}"
  gsettings set org.gnome.shell favorite-apps "$current_apps"

  cl_print "[*DONE*] - Default apps are removed from dock. \n" "green"
}


main() {
   change_appearance_color_to_dark_and_purple
   handle_dash_to_dock_to_be_installed

   change_dock_to_macos_style
   enable_auto_hide_dock
   change_click_window_action
   change_scroll_action
   enable_window_hover_show
   change_dock_background_opacity
   disable_recent_file_history
   hide_home_dir_on_desktop
   hide_mount_drive_on_dock
   hide_trashcan_on_dock
   remove_default_app_from_dock
   optimize_search_settings

   cl_print "[*INFO*] - All personal gsettings applied successfully! \n" "green"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
