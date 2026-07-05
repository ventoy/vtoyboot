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

build() {
    add_binary "dd"
    add_binary "sort"
    add_binary "head"
    add_binary "find"
    add_binary "xzcat"
    add_binary "zcat"
    add_binary "basename"
    add_binary "vtoydump"
    add_binary "vtoypartx"
    add_binary "vtoytool"

    # Add essential tools needed by the ventoy device mapper script
    add_binary "dmsetup"
    add_binary "awk"
    add_binary "grep"

    for md in $(cat /sbin/vtoydrivers 2>/dev/null); do
        if [ -n "$md" ]; then
            if modinfo -n $md 2>/dev/null | grep -q '\.ko'; then
                add_module $md
            fi
        fi
    done

    # Check if systemd hook is present
    local use_systemd=0
    for hook in "${HOOKS[@]}"; do
        if [ "$hook" = "systemd" ]; then
            use_systemd=1
            break
        fi
    done

    if [ $use_systemd -eq 1 ]; then
        # Using systemd - install service unit and executable script

        # Add the service unit to initramfs (file should already be in /usr/lib/systemd/system/)
        add_systemd_unit "ventoy-device-mapper.service"

        # Add the device mapper script with explicit 755 mode to ensure it's executable
        add_file "/usr/lib/initcpio/ventoy-device-mapper" "/usr/lib/initcpio/ventoy-device-mapper" "755"

        # Enable the service by creating symlink
        add_symlink "/usr/lib/systemd/system/initrd.target.wants/ventoy-device-mapper.service" \
                    "../ventoy-device-mapper.service"
    else
        # Using traditional busybox/udev initramfs - use runtime hook
        add_runscript
    fi
}

help() {
  cat <<HELPEOF
This hook enables ventoy device mapper in initramfs.

For systemd-based initramfs, it installs a systemd service that runs before
root device detection. For traditional busybox/udev initramfs, it uses the
standard runtime hook mechanism.

The hook automatically detects which mode to use based on the presence
of the 'systemd' hook in the HOOKS array.
HELPEOF
}
