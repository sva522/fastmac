#!/bin/bash

# Gentoo install script

# loadkeys fr
# Enable sshd
# passwd
# rc-service sshd start && ifconfig
# curl https://github.com/sva522/vm/blob/master/gentoo.sh | bash

# Erase 3 first MB
dd if=/dev/zero of=/dev/sda count=6000

# Create part file
# EFI 50Mo
# SWAP 4 Go
# btrfs root 4go (to be extended)
cat > sda.fdisk <<- EOF
label: gpt
label-id: CEBA8F38-3803-4360-B027-735C8788D3ED
device: /dev/sda
unit: sectors
first-lba: 34
last-lba: 104857566
sector-size: 512

/dev/sda1 : start=        2048, size=      102400, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, uuid=98B90393-3A38-47F8-8BEF-589CEBC7265A, name="EFI"
/dev/sda2 : start=      104448, size=     8192000, type=0657FD6D-A4AB-43C4-84E5-0933C84B4F4F, uuid=3AA1C8E8-4437-4120-AF4D-60E18D206AFE, name="swap"
/dev/sda3 : start=     8296448, size=     8192000, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, uuid=F1403144-A16A-44BE-B056-F81B33CBE014, name="root"
EOF
# Create partitions
sfdisk /dev/sda < sda.fdisk
rm -f sda.fdisk
# Force format boot partition
mkfs.fat /dev/sda1

# Expand last partition
parted /dev/sda resizepart 3 100%

# Mount root partition and resize
mkdir -p cd /mnt/gentoo
mount /dev/sda3 /mnt/gentoo
cd /mnt/gentoo
btrfs filesystem resize max .

# Create subvolume
btrfs subvolume create @
btrfs subvolume create @home
btrfs subvolume create @tmp
btrfs subvolume create @var_tmp
btrfs subvolume create @var_lib_portables
btrfs subvolume create @var_lib_machines
btrfs subvolume create @var_lib_docker
btrfs subvolume set-default @
cd /mnt
umount /mnt/gentoo
mount /dev/sda3 /mnt/gentoo -o noatime,subvol=@
cd /mnt/gentoo

# Force mise à l'heure
ntpd -q -g

# Extract base
wget https://bouncer.gentoo.org/fetch/root/all/releases/amd64/autobuilds/20201206T214503Z/stage3-amd64-systemd-20201206T214503Z.tar.xz
tar xpvf *stage3*systemd*.tar.* --xattrs-include='*.*' --numeric-owner
rm -f *stage3*systemd*.tar.*

cd /mnt/gentoo/etc/portage/

# Set gcc flags
sed -i 's/COMMON_FLAGS=.*/COMMON_FLAGS="-O2 -march=native -pipe"/' make.conf

# Add gentoo mirror
cat >> make.conf <<- EOF
#-- User settings -----------------------------------

GENTOO_MIRRORS="ftp://ftp.free.fr/mirrors/ftp.gentoo.org/ http://gentoo.modulix.net/gentoo/ http://gentoo.mirrors.ovh.net/gentoo-distfiles/ ftp://mirrors.soeasyto.com/distfiles.gentoo.org/"
ACCEPT_LICENSE="@BINARY-REDISTRIBUTABLE @EULA"

MAKEOPTS="-j2 -l 2.0"
EMERGE_DEFAULT_OPTS="${EMERGE_DEFAULT_OPTS} --jobs 2 --load-average 2"

PORTAGE_COMPRESS=xz
PORTAGE_COMPRESS_FLAGS="-9"
# Very low niceness (min is 19)
PORTAGE_NICENESS=15

EOF

# Create ebuild repo
mkdir --parents /mnt/gentoo/etc/portage/repos.conf/
cp /mnt/gentoo/usr/share/portage/config/repos.conf /mnt/gentoo/etc/portage/repos.conf/gentoo.conf
cp --dereference /etc/resolv.conf /mnt/gentoo/etc/

# Monter les système de fichier dynamique
mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev
# Non gentoo live CD, do additionnal prepare
if [ -z "$(uname -r | grep gentoo)" ]; then
    test -L /dev/shm && rm /dev/shm && mkdir /dev/shm
    mount --types tmpfs --options nosuid,nodev,noexec shm /dev/shm 
    chmod 1777 /dev/shm
fi

# chroot into
chroot /mnt/gentoo /bin/bash
source /etc/profile
export PS1="(chroot) ${PS1}"

# Create efi
mkdir -p /efi
mount /dev/sda1 /efi
ln -s /efi /boot/efi

# récupérer le dernier instantané dépot ebuild
emerge-webrsync
# Récuperer les toutes dernière modification
emerge --sync

# Get pure systemd profile
PROFILE=$(eselect profile list | grep systemd | grep stable | grep -v gnome | grep -v plasma | awk '{print $2}')
# Select profile
eselect profile set "$PROFILE"

#Sync base with current option
# Update portage itself
emerge --oneshot sys-apps/portage
# Update @world
emerge --verbose --update --deep --newuse @world

# Choose timezone for locale
echo "Europe/Paris" > /etc/timezone
emerge --config sys-libs/timezone-data

# Create locale list
cat > /etc/locale.gen <<- EOF
en_US            ISO-8859-1
en_US.UTF-8	     UTF-8
fr_FR            ISO-8859-1
fr_FR.UTF-8	     UTF-8
fr_FR@euro	     ISO-8859-15
fr_FR@euro.UTF-8 UTF-8
EOF

# Set locale
locale-gen
eselect locale set fr_FR.utf8
env-update && source /etc/profile && export PS1="(chroot) ${PS1}"

# Install kernel sources
emerge sys-kernel/gentoo-sources

# Install genkernel for auto kernel building
emerge sys-kernel/genkernel

BOOTUUID=$(blkid | grep sda1 | awk -F '"' '{print $4}')
SWAP_UUIDxxxxxxxxxxxxxxxxxxxxxxxxxx=$(blkid | grep sda2 | awk -F '"' '{print $2}')
ROOT_UUIDxxxxxxxxxxxxxxxxxxxxxxxxxx=$(blkid | grep sda3 | awk -F '"' '{print $4}')

# Create container btrfs dir
mkdir -p /var/lib/portables
mkdir -p /var/lib/machines
mkdir -p /var/lib/docker/btrfs/subvolumes

# Create fstab
cat > /etc/fstab <<- EOF
UUID=$BOOTUUID                            /efi                             vfat  defaults,noatime,dmask=0002,fmask=0023     0 1
UUID=$SWAP_UUIDxxxxxxxxxxxxxxxxxxxxxxxxxx swap                             swap  defaults                                   0 0
UUID=$ROOT_UUIDxxxxxxxxxxxxxxxxxxxxxxxxxx /                                btrfs defaults,noatime,subvol=@                  0 0
UUID=$ROOT_UUIDxxxxxxxxxxxxxxxxxxxxxxxxxx /home                            btrfs defaults,noatime,subvol=@home              0 0
UUID=$ROOT_UUIDxxxxxxxxxxxxxxxxxxxxxxxxxx /tmp                             btrfs defaults,noatime,subvol=@tmp               0 0
UUID=$ROOT_UUIDxxxxxxxxxxxxxxxxxxxxxxxxxx /var/tmp                         btrfs defaults,noatime,subvol=@var_tmp           0 0
UUID=$ROOT_UUIDxxxxxxxxxxxxxxxxxxxxxxxxxx /var/lib/portables               btrfs defaults,noatime,subvol=@var_lib_portables 0 0
UUID=$ROOT_UUIDxxxxxxxxxxxxxxxxxxxxxxxxxx /var/lib/machines                btrfs defaults,noatime,subvol=@var_lib_machines  0 0
UUID=$ROOT_UUIDxxxxxxxxxxxxxxxxxxxxxxxxxx /var/lib/docker/btrfs/subvolumes btrfs defaults,noatime,subvol=@var_lib_docker    0 0
EOF



