#!/bin/bash
# script name: all_in_one.sh
# version: 1.0.1
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
  cl_print "[*INFO*] - Setting power mode to performance..."

  # Set CPU scaling governor to performance for all CPUs
  for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
    governor_file="$cpu/cpufreq/scaling_governor"
    if [ -f "$governor_file" ]; then
      echo performance | sudo tee "$governor_file" > /dev/null
    fi
  done
  cl_print "[*INFO*] - CPU governor set to performance." "cyan"

  # Disable screen blanking (GNOME environment)
  cl_print "[*INFO*] - Disabling screen blanking and auto suspend..." "cyan"
  gsettings set org.gnome.desktop.session idle-delay 0
  gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 0
  gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 0
  cl_print "[*INFO*] - Screen blanking disabled." "cyan"

  cl_print "[*INFO*] - Power settings adjusted to performance mode. \n" "green"
}

pin_app_to_dock() {
  local app_desktop_name="$1"

  if [[ -z "$app_desktop_name" ]]; then
    cl_print "[*ERROR*] - Missing app desktop ID. Usage: pin_app_to_dock <app.desktop>" "red"
    return 1
  fi

  if ! command -v gsettings &>/dev/null; then
    cl_print "[*ERROR*] - gsettings not found. Cannot manage GNOME dock." "red"
    return 1
  fi

  local current_apps
  current_apps=$(gsettings get org.gnome.shell favorite-apps)

  if [[ "$current_apps" == *"'$app_desktop_name'"* || "$current_apps" == *"\"$app_desktop_name\""* ]]; then
    cl_print "[*INFO*] - '$app_desktop_name' is already pinned." "yellow"
  else
    # Remove brackets, if empty result, avoid extra comma
    local stripped
    stripped=$(echo "$current_apps" | sed -e "s/^\[\(.*\)\]$/\1/" )

    if [[ -z "$stripped" ]]; then
      new_list="['$app_desktop_name']"
    else
      new_list="[$stripped, '$app_desktop_name']"
    fi

    # Ensure valid GVariant: replace all single quotes with double quotes
    new_list="${new_list//\'/\"}"

    gsettings set org.gnome.shell favorite-apps "$new_list"
    cl_print "[*INFO*] - '$app_desktop_name' pinned to dock." "green"
  fi
}


do_apt_update_and_upgrade() {
  cl_print "[*INFO*] - Starting basic package update and upgrade ..."

  unlock_sudo

  cl_print "[*INFO*] - Running \`sudo apt-get update\` ..."
  sudo apt-get update

  cl_print "[*INFO*] - Running \`sudo apt-get upgrade -y\` ..."
  sudo apt-get upgrade -y

  cl_print "[*INFO*] - Package update and upgrade complete. \n" "green"
}


install_nala_and_use_faster_server() {
  cl_print "[*INFO*] - installing nala ..."

  unlock_sudo
  
  # Update package list
  sudo apt-get update
  cl_print "[*INFO*] - finish apt-get update" "cyan"

  # Install Nala
  sudo apt install -y nala
  cl_print "[*INFO*] - finish installed nala" "cyan"

  sudo nala fetch --auto -y

  cl_print "[*INFO*] - finish installing nala and setting faster server for downloading \n"
}

install_useful_packages() {
  unlock_sudo

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

    # --- X11 utilities ---
    xdotool xclip xsel xorg

    # --- File system and drive support ---
    ntfs-3g exfat-fuse

    # --- Nautilus file manager ---
    python3-gi python3-nautilus gir1.2-nautilus-4.0 procps libjs-jquery

    # --- Network and file sharing ---
    samba-common-bin net-tools lsb-release curl wget git

    # --- Media support (full GStreamer stack) ---
    gnome-sushi

    # --- Python development ---
    python3-pip python3-venv python3-dev

    # --- Terminal utilities ---
    tmux tree bash-completion fzf ripgrep

    # --- Remote desktop ---
    remmina remmina-plugin-vnc remmina-plugin-rdp

    # --- Security ---
    gnupg ufw gufw

    # --- System monitoring ---
    libgtop-2.0-11 gir1.2-gtop-2.0 gir1.2-gda-5.0 gir1.2-gsound-1.0 nvtop htop bpytop neofetch

    # --- Backup tool ---
    timeshift
    luckybackup

    # --- Personal preference utilities ---
    gnome-tweaks dconf-editor gnome-shell-extensions gnome-shell-extension-manager

    # --- Weather ---
    gnome-weather

    # --- Camera ---
    gnome-snapshot

    # --- Screenshot ---
    flameshot

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

install_pipx() {
  unlock_sudo
  sudo apt update
  sudo apt install -y pipx

  # Ensure pipx path is added for current user
  pipx ensurepath
  
  # Optional: Enable global path usage for sudo/system scripts
  sudo pipx ensurepath

  # Refresh shell environment to apply PATH changes immediately
  if [ -n "$ZSH_VERSION" ]; then
    source ~/.zshrc
  elif [ -n "$BASH_VERSION" ]; then
    source ~/.bashrc
  else
    hash -r  # refresh PATH without restarting shell
  fi

  cl_print "[*INFO*] - pipx installed successfully \n" "green"
}

install_ruff() {
  curl -LsSf https://astral.sh/uv/install.sh | sh
  cl_print "[*INFO*] - installed uv successfully" "cyan"

  uv tool install ruff@latest
  cl_print "[*INFO*] - installed ruff successfully \n" "green"
}

install_gnome_extensions_cli() {
  pipx install gnome-extensions-cli --system-site-packages
  cl_print "[*INFO*] - gnome-extensions-cli installed successfully \n" "green"
}

install_change_folder_color_tool() {
  unlock_sudo
  sudo add-apt-repository -y ppa:costales/folder-color
  sudo apt install -y folder-color

  cl_print "[*INFO*] - Folder Color installed successfully \n" "green"
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

  cl_print "[*INFO*] - finished installing OBS Studio \n" "green"
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
    cl_print "[*INFO*] - Celluloid installed successfully \n" "green"
    return 0
  else
    cl_print "[*ERROR*] - Celluloid installation failed \n" "red"
    return 1
  fi
}

install_ubuntu_cleaner() {
  cl_print "[*INFO*] - Start installing Ubuntu Cleaner ..."

  unlock_sudo
  sudo apt install software-properties-common
  sudo add-apt-repository -y ppa:gerardpuig/ppa
  sudo apt update
  sudo apt install -y ubuntu-cleaner

  cl_print "[*INFO*] - Finished installing Ubuntu Cleaner \n" "green"
}

install_telegram() {
  cl_print "[*INFO*] - Start installing Telegram ..."

  unlock_sudo
  sudo add-apt-repository -y ppa:atareao/telegram
  sudo apt update
  sudo apt install -y telegram

  cl_print "[*INFO*] - Finished installing Telegram \n" "green"
}

install_appimage_launcher() {
  # TODO: check if stable ppa is available for ubuntu 24.04
  cl_print "[*INFO*] - Start installing AppImageLauncher via .deb ..."

  unlock_sudo

  # Make sure curl is installed
  if ! command -v curl &>/dev/null; then
    cl_print "[*INFO*] - curl not found, installing curl..." "yellow"
    sudo apt update
    sudo apt install -y curl
  fi

  # Get latest release URL from GitHub API
  cl_print "[*INFO*] - Fetching latest AppImageLauncher .deb URL from GitHub..." "cyan"
  local api_url="https://api.github.com/repos/TheAssassin/AppImageLauncher/releases/latest"
  local download_url=$(curl -s "$api_url" | \
    grep "browser_download_url" | \
    grep "amd64.deb" | \
    cut -d '"' -f 4 | \
    head -n 1)

  if [[ -z "$download_url" ]]; then
    cl_print "[*ERROR*] - Failed to find .deb download URL." "red"
    return 1
  fi

  cl_print "[*INFO*] - Downloading AppImageLauncher from: $download_url" "cyan"
  local deb_file="/tmp/$(basename "$download_url")"
  wget -q --show-progress -O "$deb_file" "$download_url"

  cl_print "[*INFO*] - Installing AppImageLauncher .deb package..." "cyan"
  sudo apt install -y "$deb_file"

  cl_print "[*INFO*] - AppImageLauncher installed successfully via .deb \n" "green"
}

install_teamviewer_full_client_by_deb_file() {
  cl_print "[*INFO*] - Installing TeamViewer Full Client..." "blue"

  # Check if already installed
  if command -v teamviewer &>/dev/null; then
    cl_print "[*INFO*] - TeamViewer is already installed." "yellow"
    return 0
  fi

  # Download the latest .deb
  local url="https://download.teamviewer.com/download/linux/teamviewer_amd64.deb"
  local tmp_deb="/tmp/teamviewer_amd64.deb"

  cl_print "[*INFO*] - Downloading TeamViewer package..." "cyan"
  wget -q --show-progress -O "$tmp_deb" "$url"

  unlock_sudo
  cl_print "[*INFO*] - Installing the .deb package..." "cyan"
  sudo apt update -y
  sudo apt install -y "$tmp_deb" || {
    cl_print "[*WARN*] - Dependency issues detected. Attempting fix..." "yellow"
    sudo apt install -f -y
  }

  rm -f "$tmp_deb"
  cl_print "[*DONE*] - TeamViewer installation completed. \n" "green"
}

# install_teamviewer_full_client() {
#   cl_print "[*INFO*] - Start installing TeamViewer Full Client ..." "cyan"

#   unlock_sudo

#   # Check if already installed
#   if command -v teamviewer &>/dev/null; then
#     cl_print "[*INFO*] - TeamViewer is already installed." "yellow"
#     return 0
#   fi

#   # 1. Import TeamViewer public key
#   cl_print "[*INFO*] - Importing TeamViewer GPG key..." "blue"
#   if ! wget -qO- https://download.teamviewer.com/download/linux/signature/TeamViewer2017.asc | \
#     gpg --dearmor | sudo tee /usr/share/keyrings/teamviewer-archive-keyring.gpg > /dev/null; then
#     cl_print "[*ERROR*] - Failed to download or import GPG key." "red"
#     return 1
#   fi

#   # 2. Add TeamViewer APT repository
#   cl_print "[*INFO*] - Adding TeamViewer APT repository..." "blue"
#   echo "deb [signed-by=/usr/share/keyrings/teamviewer-archive-keyring.gpg] \
# https://linux.teamviewer.com/deb stable main" | \
#     sudo tee /etc/apt/sources.list.d/teamviewer.list > /dev/null

#   # 3. Update APT
#   cl_print "[*INFO*] - Updating package list..." "blue"
#   sudo apt update -y

#   # 4. Install TeamViewer
#   cl_print "[*INFO*] - Installing TeamViewer package..." "blue"
#   sudo apt install -y teamviewer

#   cl_print "[*DONE*] - TeamViewer Full Client installed successfully." "green"
# }


install_gstreamer() {
  cl_print "[*INFO*] - Start installing GStreamer ..."

  unlock_sudo

  # Install GStreamer and its plugins
  sudo apt install -y libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev libgstreamer-plugins-bad1.0-dev gstreamer1.0-plugins-base gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly gstreamer1.0-libav gstreamer1.0-tools gstreamer1.0-x gstreamer1.0-alsa gstreamer1.0-gl gstreamer1.0-gtk3 gstreamer1.0-qt5 gstreamer1.0-pulseaudio

  cl_print "[*INFO*] - Finished installing GStreamer \n" "green"
}

install_extra_codec() {
  cl_print "[*INFO*] - Start installing extra codecs ..." "cyan"

  unlock_sudo

  # Pre-accept Microsoft EULA for ttf-mscorefonts-installer
  echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | sudo debconf-set-selections

  # Install without prompts
  sudo apt install -y ubuntu-restricted-extras

  cl_print "[*INFO*] - Finished installing extra codecs. \n" "green"
}


reduce_swappiness () {
  cl_print "[*INFO*] - Start reducing swappiness ..."

  # Create a custom sysctl config to reduce swappiness
  sudo bash -c 'echo "vm.swappiness=10" > /etc/sysctl.d/99-swappiness.conf'

  # Apply the new setting immediately
  sudo sysctl --system

  cl_print "[*INFO*] - Finished reducing swappiness \n"
}

prompt_reboot_notification() {
  local reboot_countdown_sec=10
  local zenity_title="Ubuntu Dejavu"

  if command -v zenity &>/dev/null; then
    (
      {
        for ((i=0; i<=reboot_countdown_sec; i++)); do
          echo "$((i * 100 / reboot_countdown_sec))"
          echo "# Rebooting in $((reboot_countdown_sec - i)) second(s)..."
          sleep 1
        done
      } | zenity --progress \
           --title="${zenity_title}" \
           --text="Preparing to reboot..." \
           --percentage=0 \
           --auto-close \
           --no-cancel 2>/dev/null || {
             cl_print "[*WARN*] - Zenity failed to display. Falling back to terminal countdown." "yellow"
             sleep "$reboot_countdown_sec"
           }

      unlock_sudo
      sudo reboot
    ) &
  else
    cl_print "[*WARN*] - 'zenity' not installed. Falling back to silent countdown." "yellow"
    sleep "$reboot_countdown_sec"
    unlock_sudo
    sudo reboot
  fi
}

launcher_main() {
    cl_print "[*INFO*] - start running UBUNTU DEJAVU all in one launcher ..."
    
    change_power_to_performance_settings

    source "${THIS_FILE_PARENT_DIR}/snap/uninstall_and_block_snap_on_ubuntu.sh"
    main

    do_apt_update_and_upgrade
    install_nala_and_use_faster_server
    install_useful_packages
    install_pipx
    install_ruff
    install_gnome_extensions_cli
    install_gstreamer
    install_github_cli
    install_docker
    install_obs
    install_celluloid
    install_ubuntu_cleaner

    # pin default apps to dock
    pin_app_to_dock "org.gnome.Settings.desktop"
    pin_app_to_dock "gnome-terminal.desktop"

    # pin some apps installed by above functions
    pin_app_to_dock "org.remmina.Remmina.desktop"
    
    install_telegram
    pin_app_to_dock "telegram.desktop"

    install_teamviewer_full_client_by_deb_file
    pin_app_to_dock "com.teamviewer.TeamViewer.desktop"

    # install_anydesk
    # pin_app_to_dock "anydesk.desktop"

    install_appimage_launcher
    install_extra_codec

    # * install browsers by sub scripts    
    source "${THIS_FILE_PARENT_DIR}/apps/browser/install_firefox_by_apt_repo.sh"
    main
    pin_app_to_dock "firefox.desktop"

    source "${THIS_FILE_PARENT_DIR}/apps/browser/install_brave_by_apt_repo.sh"
    main
    pin_app_to_dock "brave-browser.desktop"

    source "${THIS_FILE_PARENT_DIR}/apps/browser/install_chrome_by_apt_repo.sh"
    main
    pin_app_to_dock "google-chrome.desktop"

    # * install IDE by sub scripts
    source "${THIS_FILE_PARENT_DIR}/apps/ide/install_sublime_text_by_apt_repo.sh"
    main
    pin_app_to_dock "sublime_text.desktop"

    source "${THIS_FILE_PARENT_DIR}/apps/ide/install_vscode_by_apt_repo.sh"
    main
    pin_app_to_dock "code.desktop"

    # * install useful apps by sub scripts
    source "${THIS_FILE_PARENT_DIR}/apps/communicate/install_discord_with_auto_update.sh"
    main
    pin_app_to_dock "discord.desktop"

    source "${THIS_FILE_PARENT_DIR}/apps/utility/install_barrier.sh"
    main

    # * install productivity tools by sub scripts
    source "${THIS_FILE_PARENT_DIR}/desktop/gnome/install_gnome_shell_pomodoro.sh"
    main
    pin_app_to_dock "org.gnome.Pomodoro.desktop"

    source "${THIS_FILE_PARENT_DIR}/apps/vm/install_qemu_vm_manager.sh"
    main

    # * install flatpak and flathub apps by sub scripts
    source "${THIS_FILE_PARENT_DIR}/flatpak/install_flatpak.sh"
    main

    source "${THIS_FILE_PARENT_DIR}/flatpak/install_flathub_apps.sh"
    main
    pin_app_to_dock "com.bitwarden.desktop.desktop" # it really name like this
    
    # * update gnome settings
    source "${THIS_FILE_PARENT_DIR}/personalize/apply_custom_keyboard_shortcuts.sh"
    main
    
    source "${THIS_FILE_PARENT_DIR}/personalize/apply_personal_gsettings.sh"
    main

    # # * install gnome extensions by sub scripts
    # source "${THIS_FILE_PARENT_DIR}/desktop/gnome/install_gnome_extensions.sh"
    # main

    source "${THIS_FILE_PARENT_DIR}/personalize/organize_apps.sh"
    main

    reduce_swappiness

    source "${THIS_FILE_PARENT_DIR}/nvidia/install_nvidia_related_packages.sh"
    main
    
    prompt_reboot_notification

    cl_print "[*INFO*] - finish running UBUNTU DEJAVU all in one launcher! \n"
}

# at the bottom of your all_in_one.sh
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    launcher_main "$@"
fi