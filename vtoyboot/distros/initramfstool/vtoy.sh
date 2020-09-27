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

rm -f /sbin/vtoydump  /sbin/vtoypartx  
rm -f /usr/share/initramfs-tools/hooks/vtoy-hook.sh  
rm -f /etc/initramfs-tools/scripts/local-top/vtoy-local-top.sh

cp -a $vtdumpcmd /sbin/vtoydump
cp -a $partxcmd  /sbin/vtoypartx
cp -a ./distros/$initrdtool/vtoy-hook.sh  /usr/share/initramfs-tools/hooks/
cp -a ./distros/$initrdtool/vtoy-local-top.sh  /etc/initramfs-tools/scripts/local-top/

echo "updating the initramfs, please wait ..."
update-initramfs -u

