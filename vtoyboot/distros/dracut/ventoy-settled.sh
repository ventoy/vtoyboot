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

type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh

if ! vtoydump > /dev/null 2>&1; then
    info 'vtoydump failed'
    return
fi

#already done
if dmsetup ls | grep -q ventoy; then
    info 'ventoy already exist'
    return
fi


vtoydump -L > /ventoy_table
dmsetup create ventoy /ventoy_table

DEVDM=/dev/mapper/ventoy

while ! [ -e $DEVDM ]; do
    sleep 0.5
done

for ID in $(vtoypartx $DEVDM -oNR | grep -v NR); do
    PART_START=$(vtoypartx  $DEVDM -n$ID -oSTART,SECTORS | grep -v START | awk '{print $1}')
    PART_SECTOR=$(vtoypartx $DEVDM -n$ID -oSTART,SECTORS | grep -v START | awk '{print $2}')
    
    echo "0 $PART_SECTOR linear $DEVDM $PART_START" > /ventoy_part_table    
    dmsetup create ventoy$ID /ventoy_part_table
done

rm -f /ventoy_table
rm -f /ventoy_part_table
