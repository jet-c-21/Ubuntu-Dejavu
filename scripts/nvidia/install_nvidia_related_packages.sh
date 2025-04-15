#!/bin/bash
# script name: install_nvidia_related_packages.sh
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

check_nvidia_driver_is_installed() {
  if ! command -v nvidia-smi &>/dev/null; then
    cl_print "[*WARN*] - NVIDIA driver is not installed. Please install the NVIDIA driver first." "yellow"
    return 1
  fi

  local nvidia_driver_version
  nvidia_driver_version=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader)
  cl_print "[*INFO*] - NVIDIA driver is installed, version: $nvidia_driver_version \n" "green"
}

unlock_sudo() {
  local result="$(use_sudo whoami)"
  cl_print "[*INFO*] - unlocked sudo for user: $result" "cyan"
}
# <<<<<<<<<<<<<<<<<<<<<<<<<<<<<< use and unlock sudo <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

install_nvidia_container_toolkit() {
  # if NVIDIA driver is not installed, log red message and return 1

  unlock_sudo
  sudo rm -rf /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
  curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
  && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

  sudo apt update
  sudo apt install -y nvidia-container-toolkit

  sudo nvidia-ctk runtime configure --runtime=docker
  cl_print "[*INFO*] - updated nvidia-ctk runtime configure" "cyan"
  
  sudo systemctl restart docker
  cl_print "[*INFO*] - restarted docker" "cyan"

  # we assume docker might be installed in first time, so user might not re-login yet, so we put || true here
  if groups "$USER" | grep -qw docker; then # Check if user is in docker group
    docker run --rm --runtime=nvidia --gpus all ubuntu nvidia-smi || true 
  else
    sudo docker run --rm --runtime=nvidia --gpus all ubuntu nvidia-smi || true
  fi

  cl_print "[*INFO*] - nvidia-container-toolkit installed successfully. \n" "green"
}

DESIERED_CUDA_VERSION="12.4"

install_cuda_on_host() {
  unlock_sudo

  local tmp_dir="/tmp/cuda_installer"
  local installer_name="cuda_12.4.0_550.54.14_linux.run"

  mkdir -p "$tmp_dir"
  cd "$tmp_dir"

  wget "https://developer.download.nvidia.com/compute/cuda/12.4.0/local_installers/$installer_name"
  
  # Run the installer with -silent and default options
  sudo sh "$installer_name" --silent --toolkit
  
  # Optional: clean up
  cd ~
  rm -rf "$tmp_dir"

  cl_print "[*INFO*] - CUDA installed successfully. \n" "green"
}


update_shell_config_for_cuda() {
  CUDA_CONFIG_BLOCK='
# >>>>>> add CUDA path >>>>>>
CUDA_VER=$(ls /usr/local | grep -oP "cuda-\\K\\d+\\.\\d+" | tail -1)
CUDA_BIN=/usr/local/cuda-$CUDA_VER/bin
CUDA_LD_BIN=/usr/local/cuda-$CUDA_VER/lib64
export PATH=$CUDA_BIN${PATH:+:$PATH}
export LD_LIBRARY_PATH=$CUDA_LD_BIN${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
# <<<<<< add CUDA path <<<<<<

'

  if [ -f "$HOME/.zshrc" ]; then
    echo "$CUDA_CONFIG_BLOCK" >> "$HOME/.zshrc"
    cl_print "[*INFO*] - CUDA path added to .zshrc" "cyan"
  fi

  if [ -f "$HOME/.bashrc" ]; then
    echo "$CUDA_CONFIG_BLOCK" >> "$HOME/.bashrc"
    cl_print "[*INFO*] - CUDA path added to .bashrc" "cyan"
  fi

  if [ "$SHELL" = "/bin/zsh" ]; then
    source "$HOME/.zshrc"
  elif [ "$SHELL" = "/bin/bash" ]; then
    source "$HOME/.bashrc"
  else
    cl_print "[*WARN*] - Cannot auto-source CUDA config in unknown shell. Please restart your terminal." "yellow"
  fi

  if command -v nvcc &>/dev/null; then
    CUDA_VER_INSTALLED=$(nvcc --version | grep -oP 'release \K[0-9]+\.[0-9]+')
    cl_print "[*INFO*] - CUDA version: $CUDA_VER_INSTALLED, CUDA is installed on host\n" "green"
  else
    cl_print "[*WARN*] - nvcc not found. CUDA may not be installed properly or not in PATH." "yellow"
  fi
}


install_cudnn_on_host() {
  unlock_sudo
  sudo apt update
  sudo apt install -y zlib1g

  # Prepare tmp location
  local tmp_dir="/tmp/cudnn_installer"
  local deb_file="cuda-keyring_1.1-1_all.deb"
  mkdir -p "$tmp_dir"
  cd "$tmp_dir"

  # Download to tmp
  wget "https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/$deb_file"

  # Install from tmp
  sudo dpkg -i "$deb_file"
  sudo apt update

  # Install cudnn from NVIDIA repo
  sudo apt -y install cudnn

  # Clean up
  cd ~
  rm -rf "$tmp_dir"

  cl_print "[*INFO*] - cuDNN installed successfully." "green"
}


main() {
  if ! check_nvidia_driver_is_installed; then
    cl_print "[*WARN*] - NVIDIA driver is not installed. task aborted." "yellow"
    return 0
  fi

  install_nvidia_container_toolkit
  install_cuda_on_host
  update_shell_config_for_cuda
  install_cudnn_on_host
  cl_print "[*INFO*] - GPU supported CUDA version: $GPU_SUPPORTED_CUDA_VERSION" "green"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
