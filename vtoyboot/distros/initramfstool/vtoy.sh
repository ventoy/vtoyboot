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
    rm -f /sbin/vtoydump  /sbin/vtoypartx  /sbin/vtoydrivers
    rm -f /usr/share/initramfs-tools/hooks/vtoy-hook.sh  
    rm -f /etc/initramfs-tools/scripts/local-top/vtoy-local-top.sh
}

vtoy_fixup() {
    #bootx64.efi missing after kali installed
    if [ -f /boot/efi/EFI/kali/grubx64.efi ]; then
        if ! [ -f /boot/efi/EFI/boot/bootx64.efi ]; then
            mkdir -p /boot/efi/EFI/boot
            cp -a /boot/efi/EFI/kali/grubx64.efi /boot/efi/EFI/boot/bootx64.efi
        fi
    fi
}

vtoy_clean_env

cp -a $vtdumpcmd /sbin/vtoydump
cp -a $partxcmd  /sbin/vtoypartx
cp -a ./tools/vtoydrivers /sbin/vtoydrivers
cp -a ./distros/$initrdtool/vtoy-hook.sh  /usr/share/initramfs-tools/hooks/
cp -a ./distros/$initrdtool/vtoy-local-top.sh  /etc/initramfs-tools/scripts/local-top/

echo "updating the initramfs, please wait ..."
update-initramfs -u


#fixup 
vtoy_fixup

