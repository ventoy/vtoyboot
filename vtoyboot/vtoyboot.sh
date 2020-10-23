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

vtoy_version=1.0.2

vtoy_get_initrdtool_type() {  
    . ./distros/initramfstool/check.sh
    . ./distros/mkinitcpio/check.sh
    . ./distros/dracut/check.sh

    if vtoy_check_initramfs_tool; then
        echo 'initramfstool'; return
    elif vtoy_check_mkinitcpio; then
        echo 'mkinitcpio'; return
    elif vtoy_check_dracut; then
        echo 'dracut'; return
    else
        echo 'unknown'; return
    fi
}

echo ''
echo '**********************************************'
echo "      vtoyboot $vtoy_version"
echo "      longpanda admin@ventoy.net"
echo "      https://www.ventoy.net"
echo '**********************************************'
echo ''

USER=$(whoami)
if [ "$USER" != "root" ]; then
    echo "Please run this script as root or use sudo"
    echo ""
    exit 1
fi

if ! [ -d ./distros ]; then
    echo "Please run the script in the right directory"
    echo ""
    exit 1
fi

initrdtool=$(vtoy_get_initrdtool_type)

if ! [ -f ./distros/$initrdtool/vtoy.sh ]; then
    echo 'Current OS is not supported!'
    exit 1
fi


#prepare vtoydump
if uname -a | grep -Eq "x86_64|amd64"; then
    vtdumpcmd=./tools/vtoydump64
    partxcmd=./tools/vtoypartx64
else
    vtdumpcmd=./tools/vtoydump32
    partxcmd=./tools/vtoypartx32
fi

chmod +x $vtdumpcmd $partxcmd

for vsh in $(ls ./distros/$initrdtool/*.sh); do
    chmod +x $vsh
done

echo "Current system use $initrdtool as initramfs tool"
. ./distros/$initrdtool/vtoy.sh 
if [ $? -eq 0 ]; then
    sync
    echo ""
    echo "vtoyboot process successfully finished."
    echo ""
else
    echo ""
    echo "vtoyboot process failed, please check."
    echo ""
    exit 1
fi
