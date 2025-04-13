#!/bin/bash
# script name: all_in_one.sh
# version: 0.0.1
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
use_sudo() { # sudo experiment wrapper function
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

THIS_FILE_PATH="$(realpath "${BASH_SOURCE[0]}")"
THIS_FILE_PARENT_DIR="$(dirname "$THIS_FILE_PATH")"

change_power_to_performance_settings() {
  cl_print "[*INFO*] - Setting power mode to performance..." "cyan"

  # Set CPU scaling governor to performance for all CPUs
  for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
    governor_file="$cpu/cpufreq/scaling_governor"
    if [ -f "$governor_file" ]; then
      echo performance | sudo tee "$governor_file" > /dev/null
    fi
  done
  cl_print "[*INFO*] - CPU governor set to performance." "green"

  # Disable screen blanking (GNOME environment)
  cl_print "[*INFO*] - Disabling screen blanking and auto suspend..." "cyan"
  gsettings set org.gnome.desktop.session idle-delay 0
  gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 0
  gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 0
  cl_print "[*INFO*] - Screen blanking disabled." "green"

  cl_print "[*INFO*] - Power settings adjusted to performance mode. \n" "green"
}


do_apt_update_and_upgrade() {
  unlock_sudo
  
  cl_print "[*INFO*] - start `sudo apt update` ..."
  sudo apt update

  cl_print "[*INFO*] - start `sudo apt upgrade -y` ..."
  sudo apt upgrade -y

  cl_print "[*INFO*] - finish basic update and upgrade \n" "green"
}

install_useful_packages() {
  unlock_sudo

  # --- good package manager utilities ---
  sudo apt install -y nala
  # sudo nala fetch --auto -y
  cl_print "[*INFO*] - finish installing nala and setting faster server for downloading \n"

  sudo apt update
  cl_print "[*INFO*] - finish `sudo apt update` from new server \n"

  # --- All required packages grouped into one list ---
  local package_list=(
    # --- Core Development Tools ---
    build-essential gcc g++ make clang cargo default-jdk
    linux-headers-$(uname -r) linux-headers-generic
    pkg-config software-properties-common ca-certificates

    # --- Common system libraries and support ---
    libc6-i386 libc6-x32 libu2f-udev

    # --- Archiving and compression tools ---
    unzip unrar p7zip bzip2 tar zip xz-utils

    # --- Disk Management ---
    gparted

    # --- GUI package manager ---
    synaptic

    # --- AppImage support ---
    libfuse2

    # --- File system and drive support ---
    ntfs-3g exfat-fuse

    # --- Network and file sharing ---
    samba-common-bin net-tools lsb-release curl wget git

    # --- Media support (full GStreamer stack) ---
    gnome-sushi

    # --- Python development ---
    python3-pip python3-venv python3-dev

    # --- Terminal utilities ---
    tmux tree bash-completion fzf ripgrep

    # --- Security ---
    gnupg ufw gufw

    # --- System monitoring ---
    htop bpytop neofetch

    # --- Personal preference utilities ---
    gnome-tweaks dconf-editor gnome-shell-extensions gnome-shell-extension-manager

    # --- Weather ---
    gnome-weather

    # --- Camera ---
    gnome-snapshot

    # --- Screen Recording ---
    simplescreenrecorder

    # --- System cleaning utilities ---
    bleachbit

    # --- Performance speed up ---
    preload

    # --- Fonts (must be last) ---
    fonts-firacode
  )

  sudo apt install -y "${package_list[@]}"

  cl_print "[*INFO*] - finish installing useful packages \n" "green"
}

install_github_cli () {
  cl_print "[*INFO*] - start installing github cli ..."
  unlock_sudo

  (type -p wget >/dev/null || (sudo apt update && sudo apt-get install wget -y)) \
	&& sudo mkdir -p -m 755 /etc/apt/keyrings \
        && out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        && cat $out | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
	&& sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
	&& echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
	&& sudo apt update \
	&& sudo apt install -y gh

  cl_print "[*INFO*] - finished installing github cli \n" "green"
}

install_docker() {
  cl_print "[*INFO*] - Start installing Docker ..." "cyan"

  unlock_sudo

  # Remove old versions if they exist
  local old_package_list=(docker docker-engine docker.io containerd runc)
  for pkg in "${old_package_list[@]}"; do
    if dpkg -l | grep -q "^ii  $pkg"; then
      cl_print "[*INFO*] - Removing old package: $pkg" "yellow"
      sudo apt remove -y "$pkg"
    fi
  done

  # Update package list and install prerequisites
  sudo apt update
  sudo apt install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

  # Add Docker’s official GPG key
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo rm -f /etc/apt/keyrings/docker.gpg
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg

  # Set up the Docker repository
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  # Install Docker components
  sudo apt update
  sudo apt install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

  # Optional: Add current user to docker group
  sudo usermod -aG docker "$USER"

  cl_print "[*INFO*] - Docker installation complete. Please log out and back in to apply group changes.\n" "green"
}


install_obs() {
  cl_print "[*INFO*] - start installing OBS Studio ..."

  unlock_sudo
  sudo add-apt-repository -y ppa:obsproject/obs-studio
  sudo apt update
  sudo apt install -y obs-studio

  cl_print "[*INFO*] - finished installing OBS Studio \n"
}

install_celluloid() {
  cl_print "[*INFO*] - Start installing Celluloid ..."

  # Unlock sudo privilege
  unlock_sudo
  
  # Add the PPA for Celluloid (gnome-mpv PPA)
  cl_print "[*INFO*] - Adding the PPA repository ..."
  sudo add-apt-repository -y ppa:xuzhen666/gnome-mpv

  # Update package list after adding PPA
  sudo apt update

  # Install Celluloid from the PPA
  sudo apt install -y celluloid

  # Check if Celluloid is installed successfully
  if command -v celluloid >/dev/null 2>&1; then
    cl_print "[*INFO*] - Celluloid installed successfully" "green"
  else
    cl_print "[*ERROR*] - Celluloid installation failed" "red"
    exit 1
  fi

  cl_print "[*INFO*] - Finished installing Celluloid \n"
}

install_ubuntu_cleaner() {
  cl_print "[*INFO*] - Start installing Ubuntu Cleaner ..."

  unlock_sudo
  sudo apt install software-properties-common
  sudo add-apt-repository -y ppa:gerardpuig/ppa
  sudo apt update
  sudo apt install -y ubuntu-cleaner

  cl_print "[*INFO*] - Finished installing Ubuntu Cleaner \n"
}

install_telegram() {
  cl_print "[*INFO*] - Start installing Telegram ..."

  unlock_sudo
  sudo add-apt-repository -y ppa:atareao/telegram
  sudo apt update
  sudo apt install -y telegram

  cl_print "[*INFO*] - Finished installing Telegram \n"
}

install_appimage_launcher() {
  cl_print "[*INFO*] - Start installing AppImageLauncher ..."

  unlock_sudo

  # Add the AppImageLauncher PPA
  sudo add-apt-repository -y ppa:appimagelauncher-team/stable

  # Update package list
  sudo apt update

  # Install AppImageLauncher
  sudo apt install -y appimagelauncher

  cl_print "[*INFO*] - Finished installing AppImageLauncher \n"
}

install_gstreamer() {
  cl_print "[*INFO*] - Start installing GStreamer ..."

  unlock_sudo

  # Install GStreamer and its plugins
  sudo apt install -y libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev libgstreamer-plugins-bad1.0-dev gstreamer1.0-plugins-base gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly gstreamer1.0-libav gstreamer1.0-tools gstreamer1.0-x gstreamer1.0-alsa gstreamer1.0-gl gstreamer1.0-gtk3 gstreamer1.0-qt5 gstreamer1.0-pulseaudio

  cl_print "[*INFO*] - Finished installing GStreamer \n"
}

install_extra_codec() {
  cl_print "[*INFO*] - Start installing extra codecs ..." "cyan"

  unlock_sudo

  # Pre-accept Microsoft EULA for ttf-mscorefonts-installer
  echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | sudo debconf-set-selections

  # Install without prompts
  sudo apt install -y ubuntu-restricted-extras

  cl_print "[*INFO*] - Finished installing extra codecs." "green"
}


reduce_swappiness () {
  cl_print "[*INFO*] - Start reducing swappiness ..."

  # Create a custom sysctl config to reduce swappiness
  sudo bash -c 'echo "vm.swappiness=10" > /etc/sysctl.d/99-swappiness.conf'

  # Apply the new setting immediately
  sudo sysctl --system

  cl_print "[*INFO*] - Finished reducing swappiness \n"
}



launcher_main() {
    cl_print "[*INFO*] - start running UBUNTU DEJAVU all in one launcher ..."
    
    change_power_to_performance_settings

    source "${THIS_FILE_PARENT_DIR}/uninstall_and_block_snap_on_ubuntu.sh"
    main

    do_apt_update_and_upgrade
    install_useful_packages
    install_gstreamer
    install_github_cli
    install_docker
    install_obs
    install_celluloid
    install_ubuntu_cleaner
    install_telegram
    install_appimage_launcher
    install_extra_codec

    # * install browsers by sub scripts    
    source "${THIS_FILE_PARENT_DIR}/install_firefox_by_apt_repo.sh"
    main

    source "${THIS_FILE_PARENT_DIR}/install_brave_by_apt_repo.sh"
    main

    source "${THIS_FILE_PARENT_DIR}/install_chrome_by_apt_repo.sh"
    main

    # * install IDE by sub scripts
    source "${THIS_FILE_PARENT_DIR}/install_sublime_text_by_apt_repo.sh"
    main

    source "${THIS_FILE_PARENT_DIR}/install_vscode_by_apt_repo.sh"
    main

    # * install useful apps by sub scripts
    source "${THIS_FILE_PARENT_DIR}/install_discord_with_auto_update.sh"
    main

    source "${THIS_FILE_PARENT_DIR}/install_barrier.sh"
    main

    # * install productivity tools by sub scripts
    source "${THIS_FILE_PARENT_DIR}/install_gnome_pomodoro.sh"
    main

    # * install flatpak and flathub apps by sub scripts
    source "${THIS_FILE_PARENT_DIR}/install_flatpak.sh"
    main

    source "${THIS_FILE_PARENT_DIR}/install_flathub_apps.sh"
    main
    
    # * update gnome settings
    source "${THIS_FILE_PARENT_DIR}/apply_custom_keyboard_shortcuts.sh"
    main
    
    source "${THIS_FILE_PARENT_DIR}/apply_personal_gsettings.sh.sh"
    main

    reduce_swappiness

    cl_print "[*INFO*] - finish running UBUNTU DEJAVU all in one launcher! \n"
}

# at the bottom of your all_in_one.sh
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    launcher_main "$@"
fi