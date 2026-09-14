### 1. Boot the official Arch ISO

Boot it in **UEFI mode**, then connect to the network.

For wired networking:

```bash
ping -c 3 archlinux.org
```

For Wi-Fi:

```bash
iwctl
station wlan0 get-networks
station wlan0 connect "Your WiFi Name"
exit
```

Verify:

```bash
ping -c 3 archlinux.org
```

### 2. Copy the project onto the live ISO

Using a USB drive containing the project:

```bash
lsblk
mkdir /mnt/usb
mount /dev/sdb1 /mnt/usb
cp -a "/mnt/usb/Vi2nano Linux" /root/vi2nano
cd /root/vi2nano
```

Or download it from GitHub:

```bash
pacman -Sy --noconfirm git
git clone https://github.com/YOUR-USER/YOUR-REPOSITORY.git /root/vi2nano
cd /root/vi2nano
```

### 3. Run the installer

For a VM disk:

```bash
./install.sh /dev/vda
```

For an NVMe disk:

```bash
./install.sh /dev/nvme0n1
```

For a SATA disk:

```bash
./install.sh /dev/sda
```

The installer will prompt before erasing the target disk. It will then install the current Arch packages, Hyprland, SDDM, Waybar, `yay`, and optionally Spacedrive.
