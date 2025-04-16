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
  local apps_to_add=(
    'org.gnome.tweaks.desktop'
    'ca.desrt.dconf-editor.desktop'
    'org.gnome.Extensions.desktop'
    'com.mattjakeman.ExtensionManager.desktop'
  )

  cl_print "[*INFO*] - Removing app assignments from any folder..." "blue"

  for app in "${apps_to_add[@]}"; do
    local all_folders
    all_folders=$(dconf list /org/gnome/desktop/app-folders/folders/)

    for folder in $all_folders; do
      # Skip target folder itself
      if [[ "$folder" == "$folder_id/" ]]; then
        continue
      fi

      local folder_path="/org/gnome/desktop/app-folders/folders/${folder}"
      local current_apps
      current_apps=$(dconf read "${folder_path}apps" 2>/dev/null || echo "[]")

      if [[ "$current_apps" == *"$app"* ]]; then
        local cleaned_apps
        cleaned_apps=$(echo "$current_apps" | sed "s/'$app',\?//g" | sed "s/\"$app\",*//g" | sed 's/,,/,/g' | sed 's/\[,\{0,1\}\]/[]/g' | sed 's/,\s*\]/]/')
        cleaned_apps="${cleaned_apps//\'/\"}"
        dconf write "${folder_path}apps" "$cleaned_apps"
        cl_print "[*INFO*] - Removed '$app' from folder '${folder}'" "yellow"
      fi
    done
  done

  cl_print "[*INFO*] - Rebuilding '${folder_id}' folder..." "blue"
  dconf write /org/gnome/desktop/app-folders/folders/${folder_id}/name "${folder_name}"
  dconf write /org/gnome/desktop/app-folders/folders/${folder_id}/translate false

  # Build a valid GVariant array like ["a", "b", "c"]
  local app_entries
  app_entries=$(printf '"%s", ' "${apps_to_add[@]}")
  app_entries="[${app_entries%, }]"

  dconf write /org/gnome/desktop/app-folders/folders/${folder_id}/apps "$app_entries"

  # Register folder in folder-children if not present
  local current_children
  current_children=$(dconf read /org/gnome/desktop/app-folders/folder-children)

  if [[ "$current_children" != *"$folder_id"* ]]; then
    if [[ "$current_children" == "[]" ]]; then
      dconf write /org/gnome/desktop/app-folders/folder-children "['$folder_id']"
    else
      local updated_children
      updated_children=$(echo "$current_children" | sed "s/^\[//;s/\]$//;s/\"//g")
      updated_children="[$updated_children, '$folder_id']"
      updated_children="${updated_children//\'/\"}"
      dconf write /org/gnome/desktop/app-folders/folder-children "$updated_children"
    fi
    cl_print "[*INFO*] - Registered '$folder_id' in folder-children." "green"
  else
    cl_print "[*INFO*] - '$folder_id' already registered in folder-children." "yellow"
  fi

  cl_print "[*DONE*] - Config Tools folder created successfully. \n" "green"
}


create_system_tool_apps_dir() {
  local folder_id="system-tools"
  local folder_name="'System Tools'"
  local apps_to_add=(
    'synaptic.desktop'
    'org.bleachbit.BleachBit.desktop'
    'bleachbit-root.desktop'
    'ubuntu-cleaner.desktop'
    'gnome-system-monitor-kde.desktop'
    'htop.desktop'
    'gnome-system-monitor.desktop'
    'gnome-system-panel.desktop'
    'gparted.desktop'
  )

  cl_print "[*INFO*] - Removing app assignments from any folder..." "blue"

  for app in "${apps_to_add[@]}"; do
    local all_folders
    all_folders=$(dconf list /org/gnome/desktop/app-folders/folders/)
    for folder in $all_folders; do
      [[ "$folder" == "$folder_id/" ]] && continue
      local folder_path="/org/gnome/desktop/app-folders/folders/${folder}"
      local current_apps
      current_apps=$(dconf read "${folder_path}apps" 2>/dev/null || echo "[]")
      if [[ "$current_apps" == *"$app"* ]]; then
        local cleaned_apps
        cleaned_apps=$(echo "$current_apps" | sed "s/'$app',\?//g" | sed "s/\"$app\",*//g" | sed 's/,,/,/g' | sed 's/\[,\{0,1\}\]/[]/g' | sed 's/,\s*\]/]/')
        cleaned_apps="${cleaned_apps//\'/\"}"
        dconf write "${folder_path}apps" "$cleaned_apps"
        cl_print "[*INFO*] - Removed '$app' from folder '${folder}'" "yellow"
      fi
    done
  done

  cl_print "[*INFO*] - Rebuilding '${folder_id}' folder..." "blue"
  dconf write /org/gnome/desktop/app-folders/folders/${folder_id}/name "${folder_name}"
  dconf write /org/gnome/desktop/app-folders/folders/${folder_id}/translate false

  local app_entries
  app_entries=$(printf '"%s", ' "${apps_to_add[@]}")
  app_entries="[${app_entries%, }]"
  dconf write /org/gnome/desktop/app-folders/folders/${folder_id}/apps "$app_entries"

  local current_children
  current_children=$(dconf read /org/gnome/desktop/app-folders/folder-children)
  if [[ "$current_children" != *"$folder_id"* ]]; then
    if [[ "$current_children" == "[]" ]]; then
      dconf write /org/gnome/desktop/app-folders/folder-children "['$folder_id']"
    else
      local updated_children
      updated_children=$(echo "$current_children" | sed "s/^\[//;s/\]$//;s/\"//g")
      updated_children="[$updated_children, '$folder_id']"
      updated_children="${updated_children//\'/\"}"
      dconf write /org/gnome/desktop/app-folders/folder-children "$updated_children"
    fi
    cl_print "[*INFO*] - Registered '$folder_id' in folder-children." "green"
  else
    cl_print "[*INFO*] - '$folder_id' already registered in folder-children." "yellow"
  fi

  cl_print "[*DONE*] - System Tools folder created successfully. \n" "green"
}



create_screen_recording_apps_dir() {
  local folder_id="screen-recording-apps"
  local folder_name="'Screen Recording Apps'"
  local apps_to_add=(
    'simplescreenrecorder.desktop'
    'com.obsproject.Studio.desktop'
  )

  cl_print "[*INFO*] - Removing app assignments from any folder..." "blue"

  for app in "${apps_to_add[@]}"; do
    local all_folders
    all_folders=$(dconf list /org/gnome/desktop/app-folders/folders/)
    for folder in $all_folders; do
      [[ "$folder" == "$folder_id/" ]] && continue
      local folder_path="/org/gnome/desktop/app-folders/folders/${folder}"
      local current_apps
      current_apps=$(dconf read "${folder_path}apps" 2>/dev/null || echo "[]")
      if [[ "$current_apps" == *"$app"* ]]; then
        local cleaned_apps
        cleaned_apps=$(echo "$current_apps" | sed "s/'$app',\?//g" | sed "s/\"$app\",*//g" | sed 's/,,/,/g' | sed 's/\[,\{0,1\}\]/[]/g' | sed 's/,\s*\]/]/')
        cleaned_apps="${cleaned_apps//\'/\"}"
        dconf write "${folder_path}apps" "$cleaned_apps"
        cl_print "[*INFO*] - Removed '$app' from folder '${folder}'" "yellow"
      fi
    done
  done

  cl_print "[*INFO*] - Rebuilding '${folder_id}' folder..." "blue"
  dconf write /org/gnome/desktop/app-folders/folders/${folder_id}/name "${folder_name}"
  dconf write /org/gnome/desktop/app-folders/folders/${folder_id}/translate false

  local app_entries
  app_entries=$(printf '"%s", ' "${apps_to_add[@]}")
  app_entries="[${app_entries%, }]"
  dconf write /org/gnome/desktop/app-folders/folders/${folder_id}/apps "$app_entries"

  local current_children
  current_children=$(dconf read /org/gnome/desktop/app-folders/folder-children)
  if [[ "$current_children" != *"$folder_id"* ]]; then
    if [[ "$current_children" == "[]" ]]; then
      dconf write /org/gnome/desktop/app-folders/folder-children "['$folder_id']"
    else
      local updated_children
      updated_children=$(echo "$current_children" | sed "s/^\[//;s/\]$//;s/\"//g")
      updated_children="[$updated_children, '$folder_id']"
      updated_children="${updated_children//\'/\"}"
      dconf write /org/gnome/desktop/app-folders/folder-children "$updated_children"
    fi
    cl_print "[*INFO*] - Registered '$folder_id' in folder-children." "green"
  else
    cl_print "[*INFO*] - '$folder_id' already registered in folder-children." "yellow"
  fi

  cl_print "[*DONE*] - Screen Recording Apps folder created successfully. \n" "green"
}




main() {
  create_config_tool_apps_dir
  create_system_tool_apps_dir
  create_screen_recording_apps_dir
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
