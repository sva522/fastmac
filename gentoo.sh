#!/bin/bash -ex

# Gentoo install script

# Create virtual machine with 25Go hdd + 8 Go ram, 4 CPU
# Installation procedure :
# https://wiki.gentoo.org/wiki/Handbook:AMD64/Full/Installation#systemd

# loadkeys fr
# Enable sshd
# passwd
# rc-service sshd start && ifconfig
# ssh && tmux new -s gentoo-install
# ctrl + b + : set -g mouse on  
# curl https://github.com/sva522/vm/blob/master/gentoo.sh | bash

## Header, set global vars #########################################

# reset
cd /tmp

# VM
root_disk=sda
swap_disk=sda
boot_nb=1
swap_nb=2
root_nb=3
swap_part=/dev/${swap_disk}${swap_nb}

# For Physical install
#root_disk=sdd
#swap_disk=nvme0n1
#boot_nb=1
#swap_nb=3
#root_nb=2
#swap_part=/dev/${swap_disk}p${swap_nb}

boot_part=/dev/${root_disk}${boot_nb}
root_part=/dev/${root_disk}${root_nb}

## Functions #########################################################

function eraseDisk(){

    umount    /mnt/gentoo/efi || true
    umount -l /mnt/gentoo/efi || true
    umount    /mnt/gentoo     || true
    umount -l /mnt/gentoo     || true
    swapoff "$swap_part"      || true

    # Erase 3 first MB
    dd if=/dev/zero of=/dev/$root_disk count=6000

    # Create part file
    # EFI 50Mo
    # SWAP 4 Go
    # btrfs root 4go (to be extended)
cat > dd_layout.fdisk <<- EOF
label: gpt
label-id: CEBA8F38-3803-4360-B027-735C8788D3ED
device: /dev/$root_disk
unit: sectors
first-lba: 34
last-lba: 104857566
sector-size: 512

$boot_part : start=        2048, size=      102400, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, uuid=98B90393-3A38-47F8-8BEF-589CEBC7265A, name="EFI"
$swap_part : start=      104448, size=     8192000, type=0657FD6D-A4AB-43C4-84E5-0933C84B4F4F, uuid=3AA1C8E8-4437-4120-AF4D-60E18D206AFE, name="swap"
$root_part : start=     8296448, size=     8192000, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, uuid=F1403144-A16A-44BE-B056-F81B33CBE014, name="root"
EOF
    # Create partitions
    sfdisk --force /dev/$root_disk < dd_layout.fdisk
    sync
    partprobe # force update partition list
    rm -f dd_layout.fdisk
    
    writeFstab

    # Expand last partition
    parted /dev/$root_disk resizepart $root_nb 100%
}

function writeFstab(){

    # Create fstab ######
    BOOTUUID=$(blkid | grep $boot_part | awk -F '"' '{print $4}')
    SWAP_UUIDxxxxxxxxxxxxxxxxxxxxxxxxxx=$(blkid | grep $swap_part | awk -F '"' '{print $2}')
    ROOT_UUIDxxxxxxxxxxxxxxxxxxxxxxxxxx=$(blkid | grep $root_part | awk -F '"' '{print $4}')

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

}

function prechroot(){

    # Erase disk in vm
    if [ "$root_disk" == "$swap_disk" ]; then
        eraseDisk
    fi

    # Re format partition
    mkfs.fat      $boot_part -n "EFI"
    mkswap        $swap_part -L "LinuxSwap"
    mkfs.btrfs -f $root_part -L "root"
    parted -s /dev/$root_disk set $boot_nb boot on
    parted -s /dev/$root_disk set $boot_nb esp on
    parted -s /dev/$swap_disk set $swap_nb swap on
    sync && partprobe || true
    swapon $swap_part

    # Mount root partition and resize
    mkdir -p /mnt/gentoo
    mount $root_part /mnt/gentoo
    cd /mnt/gentoo

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
    mount $root_part /mnt/gentoo -o noatime,subvol=@
    cd /mnt/gentoo

    # Force mise à l'heure
    ntpd -q -g

    # Extract base
    wget https://bouncer.gentoo.org/fetch/root/all/releases/amd64/autobuilds/20201206T214503Z/stage3-amd64-systemd-20201206T214503Z.tar.xz
    echo "Uncompressing base..."
    tar xpf *stage3*systemd*.tar.* --xattrs-include='*.*' --numeric-owner
    echo "Done."
    rm -f *stage3*systemd*.tar.*
    
    # Deploy gotop
    cd opt/
    wget https://github.com/xxxserxxx/gotop/releases/download/v4.0.1/gotop_v4.0.1_linux_amd64.tgz
    tar xf *gotop*t* && chmod +x gotop && rm -f *gotop*t*
    cd ..
    
    # Create fstab
    cat /etc/fstab > /mnt/gentoo/etc/fstab

    cd /mnt/gentoo/etc/portage/

    # Set gcc flags
    sed -i 's/COMMON_FLAGS=.*/COMMON_FLAGS="-O2 -march=native -pipe"/g' make.conf

    # Add gentoo mirror
cat >> make.conf <<- EOF
#-- User settings -----------------------------------

GENTOO_MIRRORS="ftp://ftp.free.fr/mirrors/ftp.gentoo.org/ http://gentoo.modulix.net/gentoo/ http://gentoo.mirrors.ovh.net/gentoo-distfiles/ ftp://mirrors.soeasyto.com/distfiles.gentoo.org/"
ACCEPT_LICENSE="@BINARY-REDISTRIBUTABLE @EULA"

MAKEOPTS="-j5 -l 8.0"
EMERGE_DEFAULT_OPTS="${EMERGE_DEFAULT_OPTS} --jobs 5 --load-average 8"

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
}

#chroot /mnt/gentoo /bin/bash
function postchroot(){

    # chroot into
    source /etc/profile
    export PS1="(chroot) ${PS1}"

    # Create efi
    mkdir -p /efi
    mount /dev/sda1 /efi
    ln -s /efi /boot/efi

    # Create container btrfs dir
    mkdir -p /var/lib/portables
    mkdir -p /var/lib/machines
    mkdir -p /var/lib/docker/btrfs/subvolumes

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

    # Now follow systemd manual
    # https://wiki.gentoo.org/wiki/Systemd
    ln -sf /proc/self/mounts /etc/mtab

    # Install kernel sources
    emerge --verbose sys-kernel/gentoo-sources

    # Install genkernel for auto kernel building
    # check for /usr in /etc/initramfs.mounts
    emerge --verbose sys-kernel/genkernel
    genkernel --install all

    emerge --verbose sys-kernel/linux-firmware
    emerge --verbose sys-firmware/intel-microcode
    emerge --verbose net-misc/openssh
    emerge --verbose app-misc/tmux
    emerge --verbose app-portage/gentoolkit # equery

    echo 'GRUB_PLATFORMS="efi-64"' >> /etc/portage/make.conf
    emerge sys-boot/grub:2
    echo 'GRUB_CMDLINE_LINUX="init=/usr/lib/systemd/systemd"/g' >> /etc/default/grub

    emerge --update --newuse --verbose sys-boot/grub:2

    grub-install /dev/$root_disk
    grub-install --target=x86_64-efi --efi-directory=/efi --removable

    grub-mkconfig -o /boot/grub/grub.cfg
    emerge sys-boot/efibootmgr

# Set network config
cat > /etc/systemd/network/50-dhcp.network << EOF
[Match]
Name=en*
 
[Network]
DHCP=yes
EOF

    ln -snf /run/systemd/resolve/resolv.conf /etc/resolv.conf 
    sync
    echo "Now exit && reboot"
}

function postreboot(){
    # Force enable keyboad layout
    localectl set-keymap fr
    localectl set-x11-keymap fr
    localectl set-locale LANG=fr_FR.UTF8

    # Enable network
    hostnamectl set-hostname 'gentoo.haut.fr'

    systemctl enable systemd-networkd.service # DHCP
    systemctl start  systemd-networkd.service 
    systemctl enable systemd-resolved.service # DNS
    systemctl start  systemd-resolved.service

    emerge --verbose sys-boot/os-prober

    env-update && source /etc/profile

    # journald volatile
}

## Main ##########################################

case "$1" in
    chroot) postchroot;;
    reboot) postreboot;;
    $*) 
        prechroot
        cp /tmp/gentoo-install.sh /mnt/gentoo/tmp/gentoo-install.sh
        chroot /mnt/gentoo /bin/bash /tmp/gentoo-install.sh chroot
    ;;
esac

