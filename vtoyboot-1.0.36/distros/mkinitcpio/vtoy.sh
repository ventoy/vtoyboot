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

. ./tools/efi_legacy_grub.sh

vtoy_clean_env() {
    rm -f /sbin/vtoydump  /sbin/vtoypartx  /sbin/vtoytool  /sbin/vtoydrivers
    rm -f /usr/lib/initcpio/hooks/ventoy
    rm -f /usr/lib/initcpio/install/ventoy
    rm -f /usr/lib/initcpio/ventoy-device-mapper
    rm -f /usr/lib/systemd/system/ventoy-device-mapper.service
}
print_init_param_warning() {
    echo -e "\033[33mWhen manually modifying hooks in /etc/mkinitcpio.conf, ventoy must be put after systemd (if enabled).\033[0m"
    sleep 1
}

print_kernel_param_warning() {
    echo ""
    echo -e "\033[33m[WARNING] ################################################################## \033[0m"
    for i in 0 1 2 3 4 5 6 7 8 9; do
        echo -e "\033[33m[WARNING] !!!! Do NOT use root=PARTUUID/PARTLABEL/gpt-auto/dissect   !!!! \033[0m"
    done
    echo -e "\033[33m[WARNING] ################################################################## \033[0m"
    echo ""
    echo -e "\033[33mVentoy device mapper does NOT expose GPT partition type metadata.\033[0m"
    echo -e "\033[33mThe following kernel parameters will FAIL to boot:\033[0m"
    echo -e "\033[33m  - root=PARTUUID=xxx\033[0m"
    echo -e "\033[33m  - root=PARTLABEL=xxx\033[0m"
    echo -e "\033[33m  - root=gpt-auto\033[0m"
    echo -e "\033[33m  - root=dissect\033[0m"
    echo ""
    echo -e "\033[32mUse these instead (they work correctly):\033[0m"
    echo -e "\033[32m  - root=LABEL=xxx       (recommended)\033[0m"
    echo -e "\033[32m  - root=UUID=xxx        (recommended)\033[0m"
    echo -e "\033[32m  - root=/dev/mapper/ventoyN\033[0m"
    echo ""
    echo -e "\033[33mCheck your bootloader config (systemd-boot, GRUB, etc.) and update\033[0m"
    echo -e "\033[33mthe kernel command line accordingly.\033[0m"
    echo ""
    sleep 5
}

vtoy_clean_env

cp -a $vtdumpcmd /sbin/vtoydump
cp -a $partxcmd  /sbin/vtoypartx
cp -a $vtoytool  /sbin/vtoytool
cp -a ./tools/vtoydrivers /sbin/vtoydrivers
cp -a ./distros/$initrdtool/ventoy-install.sh  /usr/lib/initcpio/install/ventoy
cp -a ./distros/$initrdtool/ventoy-hook.sh  /usr/lib/initcpio/hooks/ventoy

# Copy systemd-related files if they exist
if [ -f ./distros/$initrdtool/ventoy-device-mapper ]; then
    install -Dm755 ./distros/$initrdtool/ventoy-device-mapper /usr/lib/initcpio/ventoy-device-mapper
fi

if [ -f ./distros/$initrdtool/ventoy-device-mapper.service ]; then
    install -Dm644 ./distros/$initrdtool/ventoy-device-mapper.service /usr/lib/systemd/system/ventoy-device-mapper.service
fi

# Print warning about kernel parameters
print_init_param_warning
print_kernel_param_warning

echo "updating the initramfs, please wait ..."

if ! grep -q '^HOOKS=.*ventoy' /etc/mkinitcpio.conf; then
    if grep -q '^HOOKS=.*lvm' /etc/mkinitcpio.conf; then
        exthook='ventoy'
    else
        exthook='lvm2 ventoy'
    fi

    if grep -q '^HOOKS=.*encrypt' /etc/mkinitcpio.conf; then
        sed "s/\(^HOOKS=.*\)encrypt/\1 $exthook encrypt/" -i /etc/mkinitcpio.conf
    elif grep -q "^HOOKS=\"" /etc/mkinitcpio.conf; then    
        sed "s/^HOOKS=\"\(.*\)\"/HOOKS=\"\1 $exthook\"/" -i /etc/mkinitcpio.conf
    elif grep -q "^HOOKS=(" /etc/mkinitcpio.conf; then    
        sed "s/^HOOKS=(\(.*\))/HOOKS=(\1 $exthook)/" -i /etc/mkinitcpio.conf
    fi
fi

mkinitcpio -P

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
fi
