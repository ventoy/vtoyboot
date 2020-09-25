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

extdrivers='dm-mod usb-storage'

echo "updating the initramfs, please wait ..."

dracut -f --force-drivers "$extdrivers" --add "dm" \
    -i $vtdumpcmd /bin/vtoydump \
    -i $partxcmd /bin/vtoypartx \
    -i ./distros/$os/hook.sh /usr/lib/dracut/hooks/initqueue/settled/hook.sh


