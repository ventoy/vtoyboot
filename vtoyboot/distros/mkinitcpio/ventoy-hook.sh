#!/bin/bash
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

vtoy_wait_for_device() {
	local i=100

    while [ $i -gt 0 ]; do		
		if vtoydump > /dev/null 2>&1; then
			break
		else
			sleep 0.2
		fi
        i=$((i - 1))
    done
}

vtoy_device_mapper_proc() {
    #flush multipath before dmsetup
    multipath -F > /dev/null 2>&1

    vtoydump -L > /ventoy_table
    if dmsetup create ventoy /ventoy_table; then
        :
    else
        sleep 3
        multipath -F > /dev/null 2>&1
        dmsetup create ventoy /ventoy_table
    fi

    DEVDM=/dev/mapper/ventoy

    loop=0
    while ! [ -e $DEVDM ]; do
        sleep 0.5
        let loop+=1
        if [ $loop -gt 10 ]; then
            echo "Waiting for ventoy device ..." > /dev/console
        fi
        
        if [ $loop -gt 10 -a $loop -lt 15 ]; then
            multipath -F > /dev/null 2>&1
            dmsetup create ventoy /ventoy_table
        fi
    done

    for ID in $(vtoypartx $DEVDM -oNR | grep -v NR); do
        PART_START=$(vtoypartx  $DEVDM -n$ID -oSTART,SECTORS | grep -v START | awk '{print $1}')
        PART_SECTOR=$(vtoypartx $DEVDM -n$ID -oSTART,SECTORS | grep -v START | awk '{print $2}')
        
        echo "0 $PART_SECTOR linear $DEVDM $PART_START" > /ventoy_part_table    
        dmsetup create ventoy$ID /ventoy_part_table
    done

    rm -f /ventoy_table
    rm -f /ventoy_part_table
}

run_hook() {
    #check for efivarfs
    if [ -e /sys/firmware/efi ]; then
        if grep -q efivar /proc/mounts; then
            :
        else
            if [ -e /sys/firmware/efi/efivars ]; then
                mount -t efivarfs efivarfs /sys/firmware/efi/efivars  >/dev/null 2>&1
            fi
        fi
    fi
    
	if vtoydump -c >/dev/null 2>/dev/null; then
		vtoy_wait_for_device
		if vtoydump > /dev/null 2>&1; then
			vtoy_device_mapper_proc
		fi
	fi
}


