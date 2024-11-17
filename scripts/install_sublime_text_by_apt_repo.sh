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

check_if_firefox_installed() {
  # Use dpkg to check if Firefox is installed
  if dpkg -l | grep -q '^ii.*firefox'; then
    cl_print "Firefox is already installed." "green"
    return 0
  else
    cl_print "Firefox is not installed." "yellow"
    return 1
  fi
}

main() {
  # Check if Firefox is installed
  if check_if_firefox_installed; then
    cl_print "Firefox is already installed. Exit." "blue"
    exit 0
  fi

  unlock_sudo
  # 1. Create a directory to store APT repository keys if it doesn't exist
  sudo install -d -m 0755 /etc/apt/keyrings

  unlock_sudo
  # 2. Import the Mozilla APT repository signing key
  sudo apt install -y wget
  wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- | sudo tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null

  unlock_sudo
  # 3. Verify the signing key fingerprint
  gpg -n -q --import --import-options import-show /etc/apt/keyrings/packages.mozilla.org.asc | \
  awk '/pub/{getline; gsub(/^ +| +$/,""); if($0 == "35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3") \
  print "\nThe key fingerprint matches ("$0").\n"; else \
  print "\nVerification failed: the fingerprint ("$0") does not match the expected one.\n"}'

  unlock_sudo
  # 4. Add the Mozilla APT repository to your sources list
  echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" | \
  sudo tee /etc/apt/sources.list.d/mozilla.list > /dev/null

  unlock_sudo
  # 5. Configure APT to prioritize packages from the Mozilla repository
  echo '
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
' | sudo tee /etc/apt/preferences.d/mozilla > /dev/null

  unlock_sudo
  # 6. Update your package list and install Firefox
  sudo apt update && sudo apt install -y firefox

  cl_print "[*INFO*] - Firefox has been installed successfully." "green"
}

main

