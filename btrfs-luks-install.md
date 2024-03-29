# Partition disk

### Figure out the drive that you are installing to and launch fdisk on it

```
fdisk /dev/sdX
```

### Enable GPT disklabel

```
g
```

### Create EFI Partition

```
n # Create new partion
<enter> # Accept default partition number
<enter> # Accept default first sector
+500M # Partition length of 500M
t # Update partition type
1 # Select 'EFI System'
```

### Create Boot Partition

```
n # Create new partion
<enter> # Accept default partition number
<enter> # Accept default first sector
+500M # Partition length of 500M
```

### Create primary (luks encrypted, btrfs) Partition

```
n # Create new partion
<enter> # Accept default partition number
<enter> # Accept default first sector
+SIZEG # Use most of the rest of the disk
```

### Create shared with windows (ntfs) partition

```
n # Create new partion
<enter> # Accept default partition number
<enter> # Accept default first sector
<enter> # Use most of the rest of the disk
t
<enter>
11 # Use Microsoft basic data format
```

### Write the partition scheme to the disk
```
w
```

### Full paritioning command summary

```
fdisk /dev/sdX
g
n
<enter>
<enter>
+500M
t
1
n
<enter>
<enter>
+500M
n
<enter>
<enter>
+SIZEG
n
<enter>
<enter>
<enter>
t
<enter>
11
w
```

# Format disk

### Format EFI partition
```
mkfs.fat -F32 /dev/sdX1
```

### Format Boot partition
```
mkfs.ext4 /dev/sdX2
```

### Format NTFS partition
```
mkfs.ntfs /dev/sdX4
```

### Format BTRFS partition

#### Setup LUKS
```
cryptsetup -y -v --cipher=aes-xts-plain64 --key-size=512 --hash=sha512 luksFormat /dev/sdX3
```

#### Mount LUKS
```
cryptsetup luksOpen /dev/sdX3 luks
```

#### Format BTRFS
```
mkfs.btrfs -L archlinux /dev/mapper/luks
```

#### Create BTRFS subvolumes
```
mount -o compress=zstd /dev/mapper/luks /mnt
```

#### Create subvolumes
```
cd /mnt
btrfs subvolume create @
btrfs subvolume create @home
btrfs subvolume create @log
btrfs subvolume create @srv
btrfs subvolume create @pkg
btrfs subvolume create @tmp
btrfs subvolume create @images
btrfs subvolume create @backup
btrfs subvolume create @downloads
btrfs subvolume create @swap
cd /
umount /mnt
mount -o compress=zstd,subvol=@ /dev/mapper/luks /mnt
```
##### Copy-paste version:
```
cd /mnt ; btrfs subvolume create @ ; btrfs subvolume create @home ; btrfs subvolume create @log ; btrfs subvolume create @srv ; btrfs subvolume create @pkg ; btrfs subvolume create @tmp ; btrfs subvolume create @images ; btrfs subvolume create @backup ; btrfs subvolume create @downloads ; btrfs subvolume create @swap ; cd / ; umount /mnt ; mount -o compress=zstd,subvol=@ /dev/mapper/luks /mnt
```

#### Create filesystem directories
```
cd /mnt
mkdir -p {home,srv,var/{log,cache/pacman/pkg,lib/libvirt/images},tmp,backup,swap}
```

#### Associate filesystem directories to subvolumes
```
mount -o compress=zstd,subvol=@home /dev/mapper/luks home
mount -o compress=zstd,subvol=@log /dev/mapper/luks var/log
mount -o compress=zstd,subvol=@pkg /dev/mapper/luks var/cache/pacman/pkg
mount -o compress=zstd,subvol=@srv /dev/mapper/luks srv
mount -o compress=zstd,subvol=@tmp /dev/mapper/luks tmp
mount -o nodatacow,subvol=@images /dev/mapper/luks var/lib/libvirt/images
mount -o nodatacow,subvol=@backup /dev/mapper/luks backup
mount -o nodatacow,subvol=@swap /dev/mapper/luks swap
mkdir /mnt/boot
mount /dev/vda2 /mnt/boot
mkdir /mnt/boot/EFI
mount /dev/vda1 /mnt/boot/EFI
mkdir -p /mnt/mnt/ext
mount -o uid=1000,gid=1000,dmask=022,fmask=027,windows_names /dev/vda4 /mnt/mnt/ext
```

### Setup swapfile
```
touch /mnt/swap/swapfile
chmod 600 /mnt/swap/swapfile
chattr +C /mnt/swap/swapfile
dd if=/dev/zero of=/mnt/swap/swapfile bs=1M count=20480 status=progress
mkswap /mnt/swap/swapfile
swapon /mnt/swap/swapfile
```

### Disable CoW (Copy on Write) for images and backup
```
chattr +C var/lib/libvirt/images
chattr +C backup
```

##### Copy-paste version:
```
mount -o compress=zstd,subvol=@home /dev/mapper/luks home ; mount -o compress=zstd,subvol=@log /dev/mapper/luks var/log ; mount -o compress=zstd,subvol=@pkg /dev/mapper/luks var/cache/pacman/pkg ; mount -o compress=zstd,subvol=@srv /dev/mapper/luks srv ; mount -o compress=zstd,subvol=@tmp /dev/mapper/luks tmp ; mount -o nodatacow,subvol=@images /dev/mapper/luks var/lib/libvirt/images ; mount -o nodatacow,subvol=@backup /dev/mapper/luks backup ; mount -o nodatacow,subvol=@swap /dev/mapper/luks swap ; mkdir /mnt/boot ; mount /dev/vda2 /mnt/boot ; mkdir /mnt/boot/EFI ; mount /dev/vda1 /mnt/boot/EFI ; mkdir -p /mnt/mnt/ext ; mount -o uid=1000,gid=1000,dmask=022,fmask=027,windows_names /dev/vda4 /mnt/mnt/ext ; touch /mnt/swap/swapfile ; chmod 600 /mnt/swap/swapfile ; chattr +C /mnt/swap/swapfile ; dd if=/dev/zero of=/mnt/swap/swapfile bs=1M count=20480 status=progress ; mkswap /mnt/swap/swapfile ; swapon /mnt/swap/swapfile ; chattr +C var/lib/libvirt/images ; chattr +C backup
```

### Generate filesystem to table
```
mkdir /mnt/etc
genfstab -U /mnt >> /mnt/etc/fstab
```

### Enable Parallel Downloads for pacstrap
```
sed -Ei "s/^#(ParallelDownloads).*/\1 = 8/;/^#Color$/s/#//" /etc/pacman.conf
```

# Up to this point summary:
```
fdisk /dev/sdX
g
n
<enter>
<enter>
+500M
t
1
n
<enter>
<enter>
+500M
n
<enter>
<enter>
+SIZEG
n
<enter>
<enter>
<enter>
t
<enter>
11
w
```

### Rest as copy-paste
```
mkfs.fat -F32 /dev/vda1 ; mkfs.ext4 /dev/vda2 ; mkfs.ntfs /dev/vda4 ; cryptsetup -y -v --cipher=aes-xts-plain64 --key-size=512 --hash=sha512 luksFormat /dev/vda3 ; cryptsetup luksOpen /dev/vda3 luks ; mkfs.btrfs -L archlinux /dev/mapper/luks ; mount -o compress=zstd /dev/mapper/luks /mnt ; cd /mnt ; btrfs subvolume create @ ; btrfs subvolume create @home ; btrfs subvolume create @log ; btrfs subvolume create @srv ; btrfs subvolume create @pkg ; btrfs subvolume create @tmp ; btrfs subvolume create @images ; btrfs subvolume create @backup ; btrfs subvolume create @downloads ; btrfs subvolume create @swap ; cd / ; umount /mnt ; mount -o compress=zstd,subvol=@ /dev/mapper/luks /mnt ; cd /mnt ; mkdir -p {home,srv,var/{log,cache/pacman/pkg,lib/libvirt/images},tmp,backup,swap} ; mount -o compress=zstd,subvol=@home /dev/mapper/luks home ; mount -o compress=zstd,subvol=@log /dev/mapper/luks var/log ; mount -o compress=zstd,subvol=@pkg /dev/mapper/luks var/cache/pacman/pkg ; mount -o compress=zstd,subvol=@srv /dev/mapper/luks srv ; mount -o compress=zstd,subvol=@tmp /dev/mapper/luks tmp ; mount -o nodatacow,subvol=@images /dev/mapper/luks var/lib/libvirt/images ; mount -o nodatacow,subvol=@backup /dev/mapper/luks backup ; mount -o nodatacow,subvol=@swap /dev/mapper/luks swap ; mkdir /mnt/boot ; mount /dev/vda2 /mnt/boot ; mkdir /mnt/boot/EFI ; mount /dev/vda1 /mnt/boot/EFI ; mkdir -p /mnt/mnt/ext ; mount -o uid=1000,gid=1000,dmask=022,fmask=027,windows_names /dev/vda4 /mnt/mnt/ext ; touch /mnt/swap/swapfile ; chmod 600 /mnt/swap/swapfile ; chattr +C /mnt/swap/swapfile ; dd if=/dev/zero of=/mnt/swap/swapfile bs=1M count=20480 status=progress ; mkswap /mnt/swap/swapfile ; swapon /mnt/swap/swapfile ; chattr +C var/lib/libvirt/images ; chattr +C backup ; mkdir /mnt/etc ; genfstab -U /mnt >> /mnt/etc/fstab ; sed -Ei "s/^#(ParallelDownloads).*/\1 = 8/;/^#Color$/s/#//" /etc/pacman.conf
```

# Arch Install
```
pacstrap /mnt \
  base base-devel \ # Base packages
  linux linux-firmware linux-headers \ # Kernal
  grub efibootmgr os-prober \ # Bootloader
  ntfs-3g dosfstools mtools \ # File system tools for ms-dos
  networkmanager wireless_tools wpa_supplicant \ # Enable (wireless) networking
  neovim # Neovim text editor
```
#### Copy-paste version:
```
pacstrap /mnt base base-devel linux linux-firmware linux-headers grub efibootmgr os-prober ntfs-3g dosfstools mtools networkmanager wireless_tools wpa_supplicant neovim
```

## Change your "root" into the bootstrap system
```
arch-chroot /mnt
```

### Automatically startup wifi
```
systemctl enable NetworkManager
```

### Setup locale
```
nvim /etc/locale.gen
```

#### Uncomment the line
> #en_US.UTF-8 UTF-8

#### Generate locale
```
locale-gen
```

### Setup system locale
```
echo "LANG=en_US.UTF-8" > /etc/locale.conf
```

### Set root password
```
passwd
```

### Setup encryption in the initial RAM filesystem
```
nvim /etc/mkinitcpio.conf
```

#### Change the line
> HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block filesystems fsck)

#### to
> HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block **encrypt** filesystems fsck)

#### Generate new initramfs

##### If installed linux
```
mkinitcpio -p linux
```
##### If installed linux-lts
```
mkinitcpio -p linux-lts
```

## Configure boot loader
```
grub-install --target=x86_64-efi --bootloader-id=grub_uefi --recheck
```

### Configure the locale
```
mkdir -p /boot/grub/locale
cp /usr/share/locale/en\@quot/LC_MESSAGES/grub.mo /boot/grub/locale/en.mo
```

### Configure LUKS and grub

#### Grab partition UUID
```
blkid /dev/sdX3
```

#### Should have output like
> /dev/sdX3: UUID="ea3c5e4b-d8c7-4ee3-a1af-733cf80f8d44" TYPE="crypto_LUKS" PARTUUID="40d13c59-5146-0544-b694-38037ef9def0"

#### Edit grub config file
```
nvim /etc/default/grub
```

##### Change line
> GRUB_CMDLINE_LINUX=""

##### to something like (with your uuid)
> GRUB_CMDLINE_LINUX="cryptdevice=UUID=ea3c5e4b-d8c7-4ee3-a1af-733cf80f8d44:root"

#### Enable cryptodisk

##### Change line
> #GRUB_ENABLE_CRYPTODISK=y

#### to
> GRUB_ENABLE_CRYPTODISK=y

##### Generate the final config
```
grub-mkconfig -o /boot/grub/grub.cfg
```

# Test setup
```
exit
cd /
umount -R /mnt
reboot
```

# Upon reboot

### Active your connection
```
nmtui
```

# Run my startup script
### Then follow [this guide in the archlinux wiki](https://wiki.archlinux.org/title/NVIDIA#Installation)
##### 1. If you do not know what graphics card you have, find out by issuing:
```
lspci -k | grep -A 2 -E "(VGA|3D)"
```

##### 2. Determine the necessary driver version for your card by:

Visiting NVIDIA's driver download site and using the dropdown lists.
Finding the code name (e.g. NV50, NVC0, etc.) on [nouveau wiki's code names page](https://nouveau.freedesktop.org/wiki/CodeNames/) or [nouveau's GitLab](https://gitlab.freedesktop.org/nouveau/wiki/-/blob/master/sources/CodeNames.mdwn), then looking up the name in NVIDIA's [legacy card list](https://www.nvidia.com/object/IO_32667.html): if your card is not there you can use the latest driver.

##### 3. Install the appropriate driver for your card:

Note:

When installing dkms, read Dynamic Kernel Module Support#Installation
nvidia may not boot on Linux 5.18 (or later) on systems with Intel CPUs due to FS#74886/FS#74891. Until this is fixed, a workaround is disabling the Indirect Branch Tracking CPU security feature by setting the ibt=off kernel parameter from the bootloader. This security feature is responsible for mitigating a class of exploit techniques, but is deemed safe as a temporary stopgap solution.

For the Maxwell (NV110/GMXXX) series and newer, install the nvidia package (for use with the linux kernel) or nvidia-lts (for use with the linux-lts kernel) package.
If these packages do not work, nvidia-betaAUR may have a newer driver version that offers support.
Alternatively for the Turing (NV160/TUXXX) series or newer the nvidia-open package may be installed for open source kernel modules on the linux kernel (On other kernels nvidia-open-dkms must be used).
This is currently alpha quality on desktop cards, so there will be issues. Due to nvidia-open issue #282, it does not work on systems that have AMD integrated GPUs.
For the Kepler (NVE0/GKXXX) series, install the nvidia-470xx-dkmsAUR package.
For the Fermi (NVC0/GF1XX) series, install the nvidia-390xx-dkmsAUR package.
For even older cards, have a look at #Unsupported drivers.

### For a 3060: I think you should install nvidia nvidia-utils nvidia-settings nvidia-prime envycontrol lib32-nvidia-utils

##### 4. For 32-bit application support, also install the corresponding lib32 package from the multilib repository (e.g. lib32-nvidia-utils).

##### 5. Remove kms from the HOOKS array in /etc/mkinitcpio.conf and regenerate the initramfs. This will prevent the initramfs from containing the nouveau module making sure the kernel cannot load it during early boot.

###### If installed linux
```
mkinitcpio -p linux
```
###### If installed linux-lts
```
mkinitcpio -p linux-lts
```

##### 6. Reboot. The nvidia package contains a file which blacklists the nouveau module, so rebooting is necessary. 

##### Once the driver has been installed, continue to [#Xorg](https://wiki.archlinux.org/title/NVIDIA#Xorg_configuration) configuration or [#Wayland](https://wiki.archlinux.org/title/NVIDIA#Wayland).

# or...

### Add a new user (and add to wheel group)
```
useradd -mG wheel twoonesecond
```

#### Setup password for the new user
```
passwd twoonesecond
```

#### Allow wheel group to use sudo
```
EDITOR=nvim visudo
```

##### Uncomment the line

> \# %wheel ALL=(ALL:ALL) ALL

### Dump of every post-install note

### Create hostname file (will be shown to everyone on filesharing)
```
hostnamectl set-hostname myhostname
```

### Update the hosts file
```
nvim /etc/hosts
```
#### Set the contents to
> 127.0.0.1	localhost\
> 127.0.1.1	myhostname

### Set the correct timezone
```
timedatectl set-timezone America/Chicago
```

### Allow timedate to work with windows dual boot
```
timedatectl set-local-rtc 1
```

### Sync time
```
hwclock --systohc
```

### Always start timesyncd
```
systemctl enable systemd-timesyncd
```

# Looking into hibernation support using a swapfile on btrfs under luks encryption
## Create a swapfile
touch /swap
chattr +C /swapfile
lsattr /swapfile
dd if=/dev/zero of=/swapfile bs=1M count=1024 status=progress # for 1 gb
chmod 0600 /swapfile
mkswap -U clear /swapfile
swapon /swapfile


#### Add this to /etc/fstab
UUID=XXXXXX /swap btrfs subvol=@swap 0 0
/mnt/swap/swapfile none swap sw 0 0
