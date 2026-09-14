#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Run this from the Arch ISO as root."
  exit 1
fi

TARGET_DISK=${1:-}
if [[ -z "$TARGET_DISK" || ! -b "$TARGET_DISK" ]]; then
  echo "Usage: $0 /dev/disk"
  echo "Example: $0 /dev/nvme0n1"
  exit 1
fi

cat <<EOF
WARNING: this will erase every partition on $TARGET_DISK.
The installer requires UEFI mode and a wired or working network connection.
EOF
read -r -p "Type ERASE $TARGET_DISK to continue: " confirmation
[[ "$confirmation" == "ERASE $TARGET_DISK" ]] || { echo "Cancelled."; exit 1; }

read -r -p "New username: " username
read -r -p "Install yay AUR helper? [Y/n]: " yay_choice
install_yay=yes
[[ "$yay_choice" =~ ^[Nn] ]] && install_yay=no
read -r -p "Install Spacedrive from the Arch User Repository? [Y/n]: " spacedrive_choice
install_spacedrive=yes
[[ "$spacedrive_choice" =~ ^[Nn] ]] && install_spacedrive=no
read -r -s -p "Disk encryption password: " encryption_password
printf '\n'
read -r -s -p "Confirm encryption password: " encryption_password_confirm
printf '\n'
[[ "$encryption_password" == "$encryption_password_confirm" ]] || { echo "Passwords do not match."; exit 1; }

if [[ ! -d /sys/firmware/efi ]]; then
  echo "UEFI mode is required. Reboot the ISO in UEFI mode."
  exit 1
fi

loadkeys us
reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist || true
pacman -Sy --noconfirm archlinux-keyring

EFI_PARTITION="${TARGET_DISK}1"
CRYPT_PARTITION="${TARGET_DISK}2"
[[ "$TARGET_DISK" == *nvme* ]] && EFI_PARTITION="${TARGET_DISK}p1" && CRYPT_PARTITION="${TARGET_DISK}p2"

wipefs -af "$TARGET_DISK"
sgdisk --zap-all "$TARGET_DISK"
sgdisk -n 1:0:+1G -t 1:ef00 -c 1:EFI "$TARGET_DISK"
sgdisk -n 2:0:0 -t 2:8309 -c 2:cryptroot "$TARGET_DISK"
partprobe "$TARGET_DISK"

printf '%s' "$encryption_password" | cryptsetup luksFormat --type luks2 --batch-mode "$CRYPT_PARTITION" -
printf '%s' "$encryption_password" | cryptsetup open "$CRYPT_PARTITION" cryptroot --key-file -

mkfs.fat -F32 "$EFI_PARTITION"
mkfs.btrfs -f /dev/mapper/cryptroot
mount /dev/mapper/cryptroot /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@var_log
btrfs subvolume create /mnt/@var_cache
umount /mnt

mount -o noatime,compress=zstd,subvol=@ /dev/mapper/cryptroot /mnt
mkdir -p /mnt/{boot,home,.snapshots,var/log,var/cache}
mount -o noatime,compress=zstd,subvol=@home /dev/mapper/cryptroot /mnt/home
mount -o noatime,compress=zstd,subvol=@snapshots /dev/mapper/cryptroot /mnt/.snapshots
mount -o noatime,compress=zstd,subvol=@var_log /dev/mapper/cryptroot /mnt/var/log
mount -o noatime,compress=zstd,subvol=@var_cache /dev/mapper/cryptroot /mnt/var/cache
mount "$EFI_PARTITION" /mnt/boot

mapfile -t packages < <(grep -vE '^[[:space:]]*(#|$)' packages.x86_64 | tr -d '\r')
if lspci | grep -qi nvidia; then
  packages+=(nvidia-open nvidia-utils lib32-nvidia-utils)
fi
pacstrap -K /mnt "${packages[@]}"
genfstab -U /mnt >> /mnt/etc/fstab

install -d /mnt/root/vi2nano
cp -a etc sddm packages.x86_64 /mnt/root/vi2nano/
if [[ -d home ]]; then
  cp -a home /mnt/root/vi2nano/
fi
cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist

arch-chroot /mnt /bin/bash <<CHROOT
set -e
sed -i 's/^HOOKS=.*/HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt filesystems fsck)/' /etc/mkinitcpio.conf
mkinitcpio -P
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf
echo 'vi2nano' > /etc/hostname
systemctl enable NetworkManager sddm
useradd -m -G wheel -s /bin/bash "$username"
echo "$username:$username" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
if [[ "$install_yay" == yes ]]; then
  install -d -o "$username" -g "$username" /tmp/yay
  runuser -u "$username" -- git clone --depth=1 https://aur.archlinux.org/yay.git /tmp/yay
  runuser -u "$username" -- bash -c 'cd /tmp/yay && makepkg -si --noconfirm'
  rm -rf /tmp/yay
fi
if [[ "$install_spacedrive" == yes ]]; then
  if [[ "$install_yay" == yes ]]; then
    runuser -u "$username" -- yay -S --noconfirm spacedrive-bin
  else
    install -d -o "$username" -g "$username" /tmp/spacedrive-bin
    runuser -u "$username" -- git clone --depth=1 https://aur.archlinux.org/spacedrive-bin.git /tmp/spacedrive-bin
    runuser -u "$username" -- bash -c 'cd /tmp/spacedrive-bin && makepkg -si --noconfirm'
    rm -rf /tmp/spacedrive-bin
  fi
fi
bootctl install
mkdir -p /boot/loader/entries
cat > /boot/loader/loader.conf <<'LOADER'
default arch.conf
timeout 3
editor no
LOADER
cat > /boot/loader/entries/arch.conf <<ENTRY
 title Vi2nano Linux
 linux /vmlinuz-linux
 initrd /initramfs-linux.img
 options rd.luks.name=$(blkid -s UUID -o value "$CRYPT_PARTITION")=cryptroot root=UUID=$(blkid -s UUID -o value /dev/mapper/cryptroot) rootflags=subvol=@ rw
ENTRY
mkdir -p /home/$username/.config
if [[ -d /root/vi2nano/home/.config ]]; then
  cp -a /root/vi2nano/home/.config/. /home/$username/.config/
fi
install -Dm644 /root/vi2nano/etc/hypr/hyprland.conf /home/$username/.config/hypr/hyprland.conf
install -Dm644 /root/vi2nano/etc/waybar/config.jsonc /home/$username/.config/waybar/config.jsonc
install -Dm644 /root/vi2nano/etc/waybar/style.css /home/$username/.config/waybar/style.css
install -Dm644 /root/vi2nano/etc/sddm.conf.d/10-vi2nano.conf /etc/sddm.conf.d/10-vi2nano.conf
install -Dm644 /root/vi2nano/sddm/theme.conf /usr/share/sddm/themes/vi2nano/theme.conf
install -Dm644 /root/vi2nano/sddm/metadata.desktop /usr/share/sddm/themes/vi2nano/metadata.desktop
install -Dm644 /root/vi2nano/sddm/Main.qml /usr/share/sddm/themes/vi2nano/Main.qml
mkdir -p /home/$username/.config/gtk-3.0 /home/$username/.config/gtk-4.0
cat > /home/$username/.config/gtk-3.0/settings.ini <<'GTK3'
[Settings]
gtk-application-prefer-dark-theme=1
gtk-decoration-layout=close,minimize,maximize:
GTK3
cat > /home/$username/.config/gtk-4.0/settings.ini <<'GTK4'
[Settings]
gtk-application-prefer-dark-theme=1
gtk-decoration-layout=close,minimize,maximize:
GTK4
chown -R "$username:$username" /home/$username/.config
snapper -c root create-config /
systemctl enable snapper-timeline.timer snapper-cleanup.timer
CHROOT

echo "Installation complete. Unmount, close cryptroot, and reboot when ready."
