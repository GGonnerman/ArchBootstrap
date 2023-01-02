dotfilesrepo="https://github.com/GGonnerman/.dotfiles.git"
progsfile="https://raw.githubusercontent.com/GGonnerman/ArchBootstrap/master/progs.csv"
wallpaperrepo="https://github.com/GGonnerman/Wallpapers.git"

error() {
	# Log to stderr and exit with failure.
	printf "%s\n" "$1" >&2
	exit 1
}

givewarning() {
    whiptail --title "WARNING" \
        --yes-button "CONTINUE" \
        --no-button "Return..." \
        --yesno "Welcome to Gaston's arch configuration! WARNING: This script will overwrite various configurations and the entire $name user." 14 70
}

gethostname() {
	myhostname=$(whiptail --nocancel --inputbox "Enter the hostname" 10 60 3>&1 1>&2 2>&3 3>&1)
}

getuserandpass() {
	# Prompts user for new username an password.
	name=$(whiptail --inputbox "First, please enter a name for the user account." 10 60 3>&1 1>&2 2>&3 3>&1) || exit 1
	while ! echo "$name" | grep -q "^[a-z_][a-z0-9_-]*$"; do
		name=$(whiptail --nocancel --inputbox "Username not valid. Give a username beginning with a letter, with only lowercase letters, - or _." 10 60 3>&1 1>&2 2>&3 3>&1)
	done
	pass1=$(whiptail --nocancel --passwordbox "Enter a password for that user." 10 60 3>&1 1>&2 2>&3 3>&1)
	pass2=$(whiptail --nocancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
	while ! [ "$pass1" = "$pass2" ]; do
		unset pass2
		pass1=$(whiptail --nocancel --passwordbox "Passwords do not match.\\n\\nEnter password again." 10 60 3>&1 1>&2 2>&3 3>&1)
		pass2=$(whiptail --nocancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
	done
}

getveracryptpass() {
	vpass1=$(whiptail --nocancel --passwordbox "Enter a password for veracrypt." 10 60 3>&1 1>&2 2>&3 3>&1)
	vpass2=$(whiptail --nocancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
	while ! [ "$vpass1" = "$vpass2" ]; do
		unset vpass2
		vpass1=$(whiptail --nocancel --passwordbox "Passwords do not match.\\n\\nEnter password again." 10 60 3>&1 1>&2 2>&3 3>&1)
		vpass2=$(whiptail --nocancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
	done
}

getveracryptid() {
    veraid=$(whiptail --nocancel --inputbox "Enter the veracrypt device partition (e.g., /dev/vda4)" 10 60 3>&1 1>&2 2>&3 3>&1)
}

givesecondwarning() {
    whiptail --title "WARNING" \
        --yes-button "Yes, Let's do this!" \
        --no-button "No, Nevermind" \
        --yesno "Are you sure this is what you want to do? There is no confirmation that this will not break your system." 14 70
}

querycpu() {
	whiptail --title "CPU" \
		--yes-button "amd" \
		--no-button "intel" \
		--yesno "Do you have an amd or intel cpu?" 14 70
	if [[ $? -eq 0 ]]; then
		cpu="amd"
	elif [[ $? -eq 1 ]]; then
		cpu="intel"
	elif [[ $? -eq 255 ]]; then
		error "User exited."
	fi
}

adduserandpass() {
    useradd -m -G wheel -s /bin/zsh "$name" >/dev/null 2>&1 ||
		usermod -a -G wheel "$name" && mkdir -p /home/"$name" && chown "$name":"$name" /home/"$name"
	export repodir="/home/$name/.local/src"
	mkdir -p "$repodir"
	chown -R "$name":wheel "$(dirname "$repodir")"
	echo "$name:$pass1" | chpasswd
	unset pass1 pass2
}

maininstall() {
	whiptail --title "Installation" --infobox "Installing \`$1\` ($n of $total). $1 $2" 9 70
	paru --noconfirm --needed -S "$1" >/dev/null 2>&1
}

aurinstall() {
	whiptail --title "Installation" --infobox "Installing \`$1\` ($n of $total). $1 $2" 9 70
	sudo -u "$name" paru --noconfirm --needed -S "$1" >/dev/null 2>&1
}

installationloop() {
	([ -f "$progsfile" ] && cp "$progsfile" /tmp/progs.csv) ||
		curl -Ls "$progsfile" | sed '/^#/d' >/tmp/progs.csv
	total=$(wc -l </tmp/progs.csv)
	aurinstalled=$(pacman -Qqm)
	while IFS=, read -r tag program comment; do
		n=$((n + 1))
		echo "$comment" | grep -q "^\".*\"$" &&
			comment="$(echo "$comment" | sed -E "s/(^\"|\"$)//g")"

		case "$tag" in
		"A") aurinstall "$program" "$comment" ;;
		#"G") gitmakeinstall "$program" "$comment" ;;
		#"P") pipinstall "$program" "$comment" ;;
		*) maininstall "$program" "$comment" ;;
		esac
	done </tmp/progs.csv
}

givewarning || error "User exited."

gethostname || error "User exited."

getuserandpass || error "User exited."

getveracryptpass || error "User exited."

getveracryptid || error "User exited."

givesecondwarning || error "User exited."

querycpu

## Update pacman configuration settings

### Enable multilib
sed -i "/\[multilib\]/,/Include /"'s/^#//' /etc/pacman.conf

### Enable chaotic aur
if ! grep -q "chaotic-aur" /etc/pacman.conf; then
	pacman-key --recv-key FBA220DFC880C036 --keyserver keyserver.ubuntu.com
	pacman-key --lsign-key FBA220DFC880C036
	pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' 
	echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" | sudo tee -a /etc/pacman.conf
fi

### Make pacman colorful, concurrent downloads and Pacman eye-candy.
grep -q "ILoveCandy" /etc/pacman.conf || sed -i "/#VerbosePkgLists/a ILoveCandy" /etc/pacman.conf
sed -Ei "s/^#(ParallelDownloads).*/\1 = 8/;/^#Color$/s/#//" /etc/pacman.conf

### Use all cores for compilation.
sed -i "s/-j2/-j$(nproc)/;/^#MAKEFLAGS/s/^#//" /etc/makepkg.conf

### Update pacman database
sudo pacman -Syyy --noconfirm
pacman --noconfirm -S archlinux-keyring || error "Error automatically refreshing Arch keyring"

### Install a small number of progarms needed to install other programs
for x in curl paru pacman-contrib zsh veracrypt btrfs-progs arch-install-scripts; do
	pacman --noconfirm --needed -S "$x" >/dev/null 2>&1
done

### Sort the fastest mirrors
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
rankmirrors -n 12 /etc/pacman.d/mirrorlist.backup > /etc/pacman.d/mirrorlist

## Add the user account with specific password
adduserandpass || error "Error adding username and/or password."

### Umount the ntfs drive to its not open (and so its not in new etc/fstab)
umount $veraid

### Use previously created (not nested) subvolume as download folder so its excluded from backups but isnt broken
sudo -u "$name" mkdir -p /home/$name/downloads
mount -o compress=zstd,subvol=@downloads /dev/mapper/root /home/$name/downloads
chown -R "$name":wheel /home/$name/downloads
genfstab -U / > /etc/fstab

### DONT USE: This creates a NESTED SUBVOLUME STRUCTURE which seems to be annoying to deal with
### Create downloads subvol so its excluded from home snapshots (because it contains large, non-critical files)
# cd /home/$name
# sudo -u "$name" btrfs subvolume create downloads
# mount -o compress=zstd,subvol=@home/$name/downloads /dev/mapper/root /home/$name/downloads

### Setup veracrypt encrypted directory

#### Veracrypt encrypt it and format to ntfs
veracrypt -t -c --volume-type="Normal" $veraid --encryption="AES" --hash="SHA-512" --filesystem="ntfs" --password="$vpass1" --pim=0

#### Unlock the now encrypted drive and mount to /dev/mapper/ext
echo -n "$vpass1" | cryptsetup tcryptOpen $veraid ext

#### Install ntfs on the unencrypted drive
mkfs.ntfs /dev/mapper/ext

#### Mount the unencrypted ntfs to /mnt/ext
mkdir /mnt/ext
mount /dev/mapper/ext /mnt/ext

#### Setup easy decryption for the future
echo -e "\n/dev/mapper/ext /mnt/ext ntfs-3g uid=twoonesecond,gid=wheel,dmask=022,fmask=133 0 0" >> /etc/fstab
echo -n "$vpass1" > /etc/ext
echo -e "\next $veraid /etc/ext tcrypt-veracrypt" >> /etc/crypttab

### Installed the specified microcode
paru --noconfirm --needed -S "$cpu-ucode"

### Disable COW for virt-manager directory before it is filled
mkdir -p /var/lib/libvirt/images
chattr +C /var/lib/libvirt/images

### Let users run sudo without password (for aur setup)
echo '%wheel ALL=(ALL:ALL) NOPASSWD: ALL' > /etc/sudoers.d/wheel_sudo

### Run the program installation loop
installationloop 

### Use lowercase letters for xdg dirs
sudo -u "$name" mkdir -p /home/$name/.config
sudo -u "$name" echo -e 'XDG_DESKTOP_DIR="$HOME/desktop"\nXDG_DOWNLOAD_DIR="$HOME/downloads"\nXDG_TEMPLATES_DIR="$HOME/templates"\nXDG_PUBLICSHARE_DIR="$HOME/public"\nXDG_DOCUMENTS_DIR="$HOME/documents"\nXDG_MUSIC_DIR="$HOME/music"\nXDG_PICTURES_DIR="$HOME/pictures"\nXDG_VIDEOS_DIR="$HOME/videos' > /home/$name/.config/user-dirs.dirs
sudo -u "$name" echo "enabled=False" >> /home/$name/.config/user-dirs.conf

### Setup profiles for snapper

#### Create profiles for root and home
snapper -c root create-config /
snapper -c home create-config /home

#### Disable timeline snapshots in root
sed -i 's/TIMELINE_CREATE="yes"/TIMELINE_CREATE="no"/' /etc/snapper/configs/root

#### Limit to 20 snapshots for root and home
sed -i 's/NUMBER_LIMIT="50"/NUMBER_LIMIT="20"/' /etc/snapper/configs/root
sed -i 's/NUMBER_LIMIT="50"/NUMBER_LIMIT="20"/' /etc/snapper/configs/home

### Remove subvolid from fstab to allow restoring from backup
sed -i 's/subvolid=.*,//' /etc/fstab

### Set zsh as the default shell for the user
chsh -s /bin/zsh "$name" >/dev/null 2>&1
sudo -u "$name" mkdir -p "/home/$name/.cache/zsh/"

### Set hostname
hostnamectl set-hostname "$myhostname"

### Set network config
echo -e "127.0.0.1 localhost\n127.0.1.1 $myhostname"

### Set timezone and clock
timedatectl set-timezone America/Chicago
timedatectl set-local-rtc 1
hwclock --systohc
systemctl enable systemd-timesyncd

### Remove the beep
rmmod pcspkr
echo "blacklist pcspkr" >/etc/modprobe.d/nobeep.conf

# Enable snapper timeline and cleanup
systemctl enable snapper-timeline.timer
systemctl enable snapper-cleanup.timer

# Enable programs
systemctl enable cronie
systemctl enable grub-btrfsd # btrfs in grub
systemctl enable sddm # Display manager
systemctl enable upower
systemctl enable libvirtd
systemctl enable docker
systemctl enable cups # Printer service
systemctl enable auto-cpufreq # Change cpu freq on battery
systemctl enable thermald # Limit cpu temps
systemctl enable sshd # allow sshing
systemctl enable firewalld # firewall
systemctl enable bluetooth

### Update grub config after install grub-btrfs
grub-mkconfig -o /boot/grub/grub.cfg

# Set npm global install location
sudo -u "$name" mkdir "/home/$name/.local"
sudo -u "$name" npm config set prefix "/home/$name/.local"

# Copy over wallpapers
#sudo -u "$name" mkdir /home/$name/pictures/
#git clone "$wallpaperrepo" "/home/$name/pictures/wallpaper"

# Install good fonts
#aurinstall "nerd-fonts-complete" "lots of fonts"
#fc-cache -fv

# Setup sddm theme
git clone https://github.com/catppuccin/sddm.git /tmp/catppuccin
mv /tmp/catppuccin/src/catppuccin-macchiato /usr/share/sddm/themes
echo -e "[Theme]\nCurrent=catppuccin-macchiato" >> /etc/sddm.conf

# Disable sudo without password (was for aur)
rm /etc/sudoers.d/wheel_sudo

# Allow wheel users to sudo with password and allow several system commands
# (like `shutdown` to run without password).
echo "%wheel ALL=(ALL:ALL) ALL" >/etc/sudoers.d/larbs-wheel-can-sudo
echo "%wheel ALL=(ALL:ALL) NOPASSWD: /usr/bin/shutdown,/usr/bin/reboot,/usr/bin/systemctl suspend,/usr/bin/wifi-menu,/usr/bin/mount,/usr/bin/umount,/usr/bin/pacman -Syu,/usr/bin/pacman -Syyu,/usr/bin/pacman -Syyu --noconfirm,/usr/bin/loadkeys,/usr/bin/pacman -Syyuw --noconfirm,/usr/bin/pacman -S -u -y --config /etc/pacman.conf --,/usr/bin/pacman -S -y -u --config /etc/pacman.conf --" >/etc/sudoers.d/01-larbs-cmds-without-password

echo "Finished running completely!"

## How to deal with git stow and dotfiles? You have no valid ssh cert with github at time of creation...