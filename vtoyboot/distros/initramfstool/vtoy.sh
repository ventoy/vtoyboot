#!/bin/sh
#************************************************************************************
# Copyright (c) 2020, longpanda <admin@ventoy.net>
# 
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 3 of the
# License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, see <http://www.gnu.org/licenses/>.
# 
#************************************************************************************

vtoy_clean_env() {
    rm -f /sbin/vtoydump  /sbin/vtoypartx  /sbin/vtoytool  /sbin/vtoydmpatch  /sbin/vtoydrivers
    rm -f /usr/share/initramfs-tools/hooks/vtoy-hook.sh  
    rm -f /etc/initramfs-tools/scripts/local-top/vtoy-local-top.sh
}

vtoy_efi_fixup() {
    if [ -d /boot/efi/EFI ]; then
        for f in 'boot/bootx64.efi' 'boot/BOOTX64.efi' 'boot/BOOTX64.EFI' 'BOOT/bootx64.efi' 'BOOT/BOOTX64.efi' 'BOOT/BOOTX64.EFI'; do
            if [ -f /boot/efi/EFI/$f ]; then
                return
            fi
        done
    fi

    Dirs=$(ls /boot/efi/EFI)
    
    if ! [ -d /boot/efi/EFI/boot ]; then
        mkdir -p /boot/efi/EFI/boot
    fi
    
    for d in $Dirs; do
        for e in 'grubx64.efi' 'GRUBX64.EFI' 'bootx64.efi' 'BOOTX64.EFI'; do
            if [ -f "/boot/efi/EFI/$d/$e" ]; then
                cp -a "/boot/efi/EFI/$d/$e" /boot/efi/EFI/boot/bootx64.efi
                return
            fi
        done        
    done
}

. ./tools/efi_legacy_grub.sh

vtoy_clean_env

cp -a $vtdumpcmd /sbin/vtoydump
cp -a $partxcmd  /sbin/vtoypartx
cp -a $vtoytool  /sbin/vtoytool
cat /sbin/vtoydump $dmpatchko > /sbin/vtoydmpatch
cp -a ./tools/vtoydrivers /sbin/vtoydrivers
cp -a ./distros/$initrdtool/vtoy-hook.sh  /usr/share/initramfs-tools/hooks/
cp -a ./distros/$initrdtool/vtoy-local-top.sh  /etc/initramfs-tools/scripts/local-top/

echo "updating the initramfs, please wait ..."
update-initramfs -u


disable_grub_os_probe

#wrapper grub-probe
echo "grub mkconfig ..."
PROBE_PATH=$(find_grub_probe_path)
MKCONFIG_PATH=$(find_grub_mkconfig_path)
echo "PROBE_PATH=$PROBE_PATH MKCONFIG_PATH=$MKCONFIG_PATH"

if [ -e "$PROBE_PATH" -a -e "$MKCONFIG_PATH" ]; then
    wrapper_grub_probe $PROBE_PATH
    
    GRUB_CFG_PATH=$(find_grub_config_path)
    if [ -f "$GRUB_CFG_PATH" ]; then
        echo "$MKCONFIG_PATH -o $GRUB_CFG_PATH"
        $MKCONFIG_PATH -o $GRUB_CFG_PATH
    else
        echo "$MKCONFIG_PATH null"
        $MKCONFIG_PATH > /dev/null 2>&1
    fi
fi

#efi fixup 
if [ -e /sys/firmware/efi ]; then
    if [ -e /dev/mapper/ventoy ]; then
        echo "This is ventoy enviroment"
    else
        update_grub_config
        install_legacy_bios_grub
    fi
    
    if [ "$1" = "-s" ]; then
        recover_shim_efi
    else
        replace_shim_efi
    fi
    
    vtoy_efi_fixup
fi

