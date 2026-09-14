# Vi2nano Linux

A personal Arch Linux desktop build for AMD-first Wayland systems with NVIDIA support.

## Profile

- Hyprland on Wayland
- Waybar bottom dock with `nwg-drawer`
- SDDM graphical login
- LUKS2 + Btrfs subvolumes
- Snapper package snapshots
- Dark, polished hacker/macOS-inspired styling
- Firefox, URXVT, Vim, VS Code, ONLYOFFICE, and Proton web shortcuts

## Build and install

This installer is intended to be run from the official Arch ISO in UEFI mode. It is destructive only after you explicitly provide a target disk and confirm the warning.

```bash
./install.sh /dev/nvme0n1
```

Review the script before use. Test in a VM first. The installer will erase the selected disk.

### Build a Vi2nano install image

On an Arch Linux build system, install `archiso`, clone this repository, and run:

```bash
sudo pacman -S archiso
sudo ./build-iso.sh
```

The ISO is created in `out/`. Boot it in UEFI mode, connect to the network, then run:

```bash
cd /root/vi2nano
./install.sh /dev/nvme0n1
```

The installer still requires explicit confirmation before erasing a disk. Build the image from a clean checkout whenever configuration changes are made.

## Layout

- `install.sh`: encrypted Btrfs installation flow
- `packages.x86_64`: package manifest
- `etc/`: system configuration to copy into the target
- `home/`: optional user configuration templates
- `sddm/`: graphical login theme and metadata

GTK 3 and GTK 4 client-side window controls are configured on the left in the order close, minimize, maximize. Qt applications and applications that draw their own title bars may not honor this setting; Hyprland does not provide a global server-side title bar to reposition those controls.

## Current scope

The installer creates a clean Arch installation and copies the desktop configuration. GPU-specific packages are selected using PCI detection. `yay` and Spacedrive are offered by default through AUR packages; decline either prompt if you want a base installation without them. If `yay` is enabled, it installs Spacedrive with `yay -S spacedrive-bin`. AUR packages are user-produced build scripts and should be reviewed before installation.
