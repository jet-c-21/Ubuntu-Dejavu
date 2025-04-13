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


create_config_tool_apps_dir() {
  local folder_id="config-tools"
  local folder_name="'Config Tools'"
  local apps_list="['org.gnome.tweaks.desktop', 'dconf-editor.desktop', 'org.gnome.Extensions.desktop', 'com.mattjakeman.ExtensionManager.desktop']"

  cl_print "[*INFO*] - Creating app folder '${folder_name}' with config tools..." "blue"

  dconf write /org/gnome/desktop/app-folders/folders/${folder_id}/name "${folder_name}"
  dconf write /org/gnome/desktop/app-folders/folders/${folder_id}/translate false
  dconf write /org/gnome/desktop/app-folders/folders/${folder_id}/apps "${apps_list}"

  # Check if already in folder-children
  local current_children
  current_children=$(dconf read /org/gnome/desktop/app-folders/folder-children)

  if [[ "$current_children" == *"${folder_id}"* ]]; then
    cl_print "[*INFO*] - '${folder_id}' already exists in folder-children. Skipping append." "yellow"
  else
    dconf write /org/gnome/desktop/app-folders/folder-children "['${folder_id}']"
    cl_print "[*INFO*] - Added '${folder_id}' to folder-children." "green"
  fi

  cl_print "[*DONE*] - Config Tools folder created successfully." "green"
}


main() {
  create_config_tool_apps_dir
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
