# Ubuntu-Dejavu

Tired of the same Ubuntu setup déjà vu over and over? Ubuntu-Dejavu is what you need

# Must Installed gnome extensions

- `Blur my Shell`
- `Emoji Copy`
- `TopHat`
- `NVIDIA GPU Stats Tool`
- `Pano - Clipboard Manager` (not support on ubuntu 24.04 yet, you have to install alpha version from their github)
- `No overview at start-up`
- `Weather O'Clock`
- `Compiz windows effect`
- `Compiz alike magic lamp effect`
- `Desktop Cube`
- `Wiggle`
- `Burn My Windows`: choose `Apparition`, `Glide`, and `Mushroom` effects
- `OpenWeather Refined`
- `Status Area Horizontal Spacing`


# VMWare Workstation

```bash
install_vmware_workstation_on_linux() {
  # Usage: install_vmware_workstation_on_linux ~/Downloads/VMware-Workstation-Full-17.5.0-xxxx.bundle
  local bundle_file="$1"

  if [[ -z "$bundle_file" || ! -f "$bundle_file" ]]; then
    echo "[ERROR] Please provide the path to the VMware .bundle file." >&2
    echo "Usage: install_vmware_workstation_on_linux /path/to/VMware-Workstation-Full-XX.X.X.bundle" >&2
    return 1
  fi

  echo "[INFO] Making the bundle executable..."
  chmod +x "$bundle_file"

  echo "[INFO] Installing required packages..."
  sudo apt update
  sudo apt install -y build-essential gcc make linux-headers-$(uname -r)

  echo "[INFO] Running VMware installer..."
  if ! sudo "$bundle_file"; then
    echo "[WARN] GUI installer failed, trying console mode..."
    sudo "$bundle_file" --console || {
      echo "[ERROR] VMware installer failed." >&2
      return 1
    }
  fi

  echo "[INFO] Enabling VMware services to start at boot..."
  sudo systemctl enable vmware
  sudo systemctl enable vmware-networks
  sudo systemctl enable vmware-usbarbitrator

  echo "[INFO] Starting VMware services..."
  sudo systemctl start vmware
  sudo systemctl start vmware-networks
  sudo systemctl start vmware-usbarbitrator

  echo "[INFO] Configuring VMware kernel modules..."
  sudo vmware-modconfig --console --install-all || true

  echo "[DONE] VMware Workstation installation complete."
}
install_vmware_workstation_on_linux
```