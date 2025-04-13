#!/bin/bash
# script name: apply_personal_gsettings.sh

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


add_xkill_kb_shortcut() {
  local name="Xkill"
  local command="xkill"
  local binding="<Control>Escape"
  local base_path="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings"
  local key="org.gnome.settings-daemon.plugins.media-keys.custom-keybinding"

  cl_print "[*INFO*] - Adding custom keyboard shortcut for Xkill..." "cyan"

  # Get current list of keybindings
  local current_list
  current_list=$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings)

  # Remove '@as []' if it's empty
  if [[ "$current_list" == "@as []" ]]; then
    current_list="[]"
  fi

  # Generate new unique custom path
  local index=0
  local new_binding="${base_path}/custom${index}/"
  while [[ "$current_list" == *"$new_binding"* ]]; do
    ((index++))
    new_binding="${base_path}/custom${index}/"
  done

  # Append new binding to the list
  local updated_list
  if [[ "$current_list" == "[]" ]]; then
    updated_list="['${new_binding}']"
  else
    updated_list=$(echo "$current_list" | sed "s/]$/, '${new_binding}']/")
  fi
  gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "$updated_list"

  # Set shortcut properties
  gsettings set "$key:$new_binding" name "$name"
  gsettings set "$key:$new_binding" command "$command"
  gsettings set "$key:$new_binding" binding "$binding"

  cl_print "[*INFO*] - Shortcut <Ctrl>+Escape for Xkill added successfully." "green"
}




main() {
  add_xkill_kb_shortcut

  cl_print "[*INFO*] - Custom keyboard shortcuts applied successfully." "green"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
