#!/bin/bash
# script name: apply_custom_keyboard_shortcuts.sh

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
  local command="whoami"
  local result="$(use_sudo "$command")"
  echo "[*INFO*] - unlock $result privilege"
}
# <<<<<<<<<<<<<<<<<<<<<<<<<<<<<< use and unlock sudo <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


add_custom_kb_shortcut() {
  local name="$1"
  local command="$2"
  local binding="$3"
  local index="$4"

  local keybinding_path="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings"
  local new_entry="${keybinding_path}/custom${index}/"

  current_bindings=$(dconf read "$keybinding_path")

  if [[ "$current_bindings" != *"custom${index}"* ]]; then
    if [[ "$current_bindings" =~ ^\[.*\]$ ]]; then
      updated_bindings=$(echo "$current_bindings" | sed "s/]$/, '${new_entry}']/")
    else
      updated_bindings="['${new_entry}']"
    fi
    dconf write "$keybinding_path" "$updated_bindings"
  fi

  dconf write "${new_entry}name" "'${name}'"
  dconf write "${new_entry}command" "'${command}'"
  dconf write "${new_entry}binding" "'${binding}'"

  cl_print "[*INFO*] - Shortcut '${name}' set successfully! \n" "green"
}


main() {
  add_custom_kb_shortcut "Xkill" "xkill" "<Control>Escape" 0
  add_custom_kb_shortcut "Flameshot GUI" "flameshot gui" "<Control>Print" 1

  cl_print "[*INFO*] - Custom keyboard shortcuts applied successfully. \n" "green"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
