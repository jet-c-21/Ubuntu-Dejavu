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

check_if_chrome_installed() {
  # Use dpkg to check if chrome is installed
  if dpkg -l | grep -q '^ii.*chrome'; then
    cl_print "chrome is already installed." "green"
    return 0
  else
    cl_print "chrome is not installed." "yellow"
    return 1
  fi
}

main() {
  # Check if chrome is installed
  if check_if_chrome_installed; then
    cl_print "chrome is already installed. Exit."
    exit 0
  fi

  cl_print "[*INFO*] - chrome has been installed successfully. \n" "green"
}

main

