#!/bin/bash
# script name: install_nvidia_driver.sh
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

install_nvidia_container_toolkit() {
  # if nvidia dirver is not installed, log red message and return 1

  unlock_sudo

  curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
  && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

  sudo apt update
  sudo apt install -y nvidia-container-toolkit

  sudo nvidia-ctk runtime configure --runtime=docker
  sudo systemctl restart docker

  docker run --rm --runtime=nvidia --gpus all ubuntu nvidia-smi

  cl_print "[*INFO*] - nvidia-container-toolkit installed successfully. \n" "green"
}

DESIERED_CUDA_VERSION="12.4"

install_cuda_on_host() {
  unlock_sudo

  wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb
  sudo dpkg -i cuda-keyring_1.1-1_all.deb
  sudo apt update
  sudo apt install -y cuda-toolkit-12-4
}

update_shell_config_for_cuda() {
  if [ -f "$HOME/.zshrc" ]; then
    echo '

# >>>>>> add CUDA path >>>>>>
CUDA_VER=$(ls /usr/local | grep -oP 'cuda-\K\d+\.\d+' | tail -1)
CUDA_BIN=/usr/local/cuda-$CUDA_VER/bin
CUDA_LD_BIN=/usr/local/cuda-$CUDA_VER/lib64
export PATH=$CUDA_BIN${PATH:+:$PATH}
export LD_LIBRARY_PATH=$CUDA_LD_BIN${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
# <<<<<< add CUDA path <<<<<<

' >> "$HOME/.zshrc"

    source "$HOME/.zshrc"
  fi

  if [ -f "$HOME/.bashrc" ]; then
    echo '

# >>>>>> add CUDA path >>>>>>
CUDA_VER=$(ls /usr/local | grep -oP 'cuda-\K\d+\.\d+' | tail -1)
CUDA_BIN=/usr/local/cuda-$CUDA_VER/bin
CUDA_LD_BIN=/usr/local/cuda-$CUDA_VER/lib64
export PATH=$CUDA_BIN${PATH:+:$PATH}
export LD_LIBRARY_PATH=$CUDA_LD_BIN${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
# <<<<<< add CUDA path <<<<<<

' >> "$HOME/.bashrc"

    source "$HOME/.bashrc"
  fi
}


main() {
#  install_nvidia_container_toolkit
  install_cuda_on_host
  update_shell_config_for_cuda
  cl_print "[*INFO*] - GPU supported CUDA version: $GPU_SUPPORTED_CUDA_VERSION" "green"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
