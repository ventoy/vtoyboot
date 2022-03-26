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

PREREQ="dmsetup"
prereqs() {
    echo "$PREREQ"
}

case $1 in
    prereqs)
       prereqs
       exit 0
       ;;
esac

. /usr/share/initramfs-tools/hook-functions

# Begin real processing below this line

for md in $(cat /sbin/vtoydrivers); do
    if [ -n "$md" ]; then
        if modinfo -n $md 2>/dev/null | grep -q '\.ko'; then
            force_load $md
        fi
    fi
done

for ef in dd sort head find basename xzcat zcat; do
    for vp in /bin /sbin /usr/bin /usr/sbin; do
        if [ -f $vp/$ef ]; then
            copy_exec $vp/$ef /sbin
            break
        fi
    done
done

copy_exec /sbin/vtoytool    /sbin
copy_exec /sbin/vtoydmpatch /sbin
copy_exec /sbin/vtoypartx   /sbin
copy_exec /sbin/vtoydump    /sbin
