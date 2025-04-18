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




install_gnome_ext_hanabi_on_nobel_numbat() {
  cl_print "[*INFO*] - Installing gnome ext hanabi on nobel numbat ..." "cyan"
  unlock_sudo

  # Essential tools
  sudo apt install -y git meson

  # GTK4 and related media support
  sudo apt install -y libgtk-4-dev libgtk-4-media-gstreamer libadwaita-1-dev

  # GStreamer core and plugin development libraries
  sudo apt install -y \
    libgstreamer1.0-dev \
    libgstreamer-plugins-base1.0-dev \
    libgstreamer-plugins-good1.0-dev \
    libgstreamer-plugins-bad1.0-dev

  # GStreamer runtime plugins (base, good, bad, ugly, libav, gl)
  sudo apt install -y \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-ugly \
    gstreamer1.0-libav \
    gstreamer1.0-gl

  # GObject Introspection bindings for GStreamer (for GNOME extensions)
  sudo apt install -y \
    gir1.2-gst-plugins-base-1.0 \
    gir1.2-gst-plugins-bad-1.0

  # GNOME plugin system
  sudo apt install -y libpeas-2-dev

  # Build & install
  cd /tmp
  rm -rf clapper
  git clone https://github.com/Rafostar/clapper.git
  cd clapper
  meson setup build --prefix=/usr \
      -Dgst-plugin=enabled \
      -Dglimporter=enabled \
      -Dgluploader=enabled \
      -Drawimporter=enabled
  cd build
  meson compile
  sudo meson install

  cl_print "[*INFO*] - clapper installed successfully!" "cyan"

  # install hanabi
  cd /tmp
  git clone https://github.com/jeffshee/gnome-ext-hanabi.git
  cd gnome-ext-hanabi
  ./run.sh install

  cl_print "[*INFO*] - gnome ext hanabi on nobel numbat installed successfully, please restart GNOME Shell and enable Hanabi extension! \n" "green"
}

main() {
  install_gnome_ext_hanabi_on_nobel_numbat
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
