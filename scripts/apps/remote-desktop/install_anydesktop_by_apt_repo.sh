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

purge_anydesk() {
  cl_print "[*INFO*] - Start purging AnyDesk ..."

  unlock_sudo

  # Remove the AnyDesk package
  sudo apt purge -y anydesk

  # Remove the AnyDesk repository list
  sudo rm -f /etc/apt/sources.list.d/anydesk-stable.list

  # Remove the AnyDesk GPG key
  sudo rm -f /etc/apt/keyrings/keys.anydesk.com.asc

  # Clean up unused dependencies
  sudo apt autoremove -y
  sudo apt clean

  cl_print "[*INFO*] - Finished purging AnyDesk \n" "green"
}

 install_anydesk() {
   # this ppa version will make fullscreen and resolution behavior weird
   cl_print "[*INFO*] - Start installing AnyDesk ..."

   unlock_sudo

   # Add the AnyDesk GPG key
   sudo apt update
   sudo apt install -y ca-certificates curl apt-transport-https
   sudo install -m 0755 -d /etc/apt/keyrings

   sudo rm -f /etc/apt/keyrings/keys.anydesk.com.asc
   sudo curl -fsSL https://keys.anydesk.com/repos/DEB-GPG-KEY -o /etc/apt/keyrings/keys.anydesk.com.asc
   sudo chmod a+r /etc/apt/keyrings/keys.anydesk.com.asc

   # Add the AnyDesk apt repository
   echo "deb [signed-by=/etc/apt/keyrings/keys.anydesk.com.asc] https://deb.anydesk.com all main" | sudo tee /etc/apt/sources.list.d/anydesk-stable.list > /dev/null

   # Update apt caches and install the AnyDesk client
   sudo apt update
   sudo apt install -y anydesk

   cl_print "[*INFO*] - Finished installing AnyDesk \n" "green"
 }

main() {
  install_anydesk
#  purge_anydesk
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
