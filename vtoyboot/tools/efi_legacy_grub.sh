#!/bin/sh


disable_grub_os_probe() {
    for probe in 30_os-prober; do
        probe_cfg=/etc/grub.d/$probe
        if [ -f $probe_cfg ]; then
            if grep -q 'VTOYBOOT_FLAG' $probe_cfg; then
                :
            else
                sed "1a#VTOYBOOT_FLAG" -i $probe_cfg
                sed "1aexit 0" -i $probe_cfg
            fi
        fi
    done
}

find_grub_probe_path() {
    if which grub-probe >/dev/null 2>&1; then
        which grub-probe
    elif which grub2-probe >/dev/null 2>&1; then
        which grub2-probe
    else
        echo "XXX"
    fi
}

find_grub_mkconfig_path() {
    if which grub-mkconfig >/dev/null 2>&1; then
        which grub-mkconfig
    elif which grub2-mkconfig >/dev/null 2>&1; then
        which grub2-mkconfig
    else
        echo "XXX"
    fi
}

find_grub_config_path() {
    for i in grub.cfg grub2.cfg grub-efi.cfg grub2-efi.cfg; do
        if readlink -f -e /etc/$i > /dev/null; then
            cfgfile=$(readlink -f -e /etc/$i)
            echo $cfgfile
            return
        fi
    done
    
    for t in /boot/grub/grub.cfg /boot/grub2/grub.cfg; do
        if grep -q 'BEGIN' $t 2>/dev/null; then
            echo $t
            return
        fi
    done
    
    echo "xx"
}

update_grub_config() {
    if update-grub -V > /dev/null 2>&1; then
        GRUB_UPDATE=update-grub
    elif update-grub2 -V > /dev/null 2>&1; then
        GRUB_UPDATE=update-grub2
    else
        vgrubcfg=$(find_grub_config_path)
        mkconfig=$(find_grub_mkconfig_path)

        if [ -f $mkconfig -a -f $vgrubcfg ]; then
            GRUB_UPDATE="$mkconfig -o $vgrubcfg"
        else
            echo "update-grub no need"
            return
        fi
    fi

    UPDATE=0

    if [ -f /etc/default/grub ]; then
        if grep -q 'GRUB_TIMEOUT=0' /etc/default/grub; then
            UPDATE=1
            sed 's/GRUB_TIMEOUT=0/GRUB_TIMEOUT=30/' -i /etc/default/grub
        fi
        
        if grep -q 'GRUB_TIMEOUT_STYLE=hidden' /etc/default/grub; then
            UPDATE=1
            sed 's/GRUB_TIMEOUT_STYLE=hidden/GRUB_TIMEOUT_STYLE=menu/' -i /etc/default/grub
        fi
    fi
    
    if [ $UPDATE -eq 1 ]; then
        echo "update grub config"
        $GRUB_UPDATE
    fi
}

print_bios_grub_warning() {    
    echo -e "\033[33m[WARNING] ################################################################## \033[0m"
    for i in 0 1 2 3 4 5 6 7 8 9; do
        echo -e "\033[33m[WARNING] !!!! This vhd/vdi/raw file will only be bootable in UEFI mode !!!! \033[0m"
    done
    echo -e "\033[33m[WARNING] ################################################################## \033[0m"
    sleep 3
}

install_legacy_bios_grub() {
    all_modules=""

    if [ -f /boot/grub/grub.cfg ]; then
        PREFIX=/boot/grub
        MOD_PATH=/boot/grub
        CFG=grub.cfg
                
        if [ -f /boot/efi/EFI/UOS/grub.cfg ]; then
            PREFIX=/EFI/UOS
        elif [ -f /boot/efi/EFI/ubuntu/grub.cfg ]; then
            PREFIX=/EFI/ubuntu
        fi
    else
        for i in grub.cfg grub2.cfg grub-efi.cfg grub2-efi.cfg; do
            if readlink -f -e /etc/$i > /dev/null; then
                cfgfile=$(readlink -f -e /etc/$i)
                MOD_PATH=${cfgfile%/*}
                
                PREFIX=$MOD_PATH
                if echo $MOD_PATH | grep -q '^/boot/efi'; then
                    if mountpoint -q /boot/efi; then
                        PREFIX=${MOD_PATH#/boot/efi}
                    fi
                fi
                
                CFG=${cfgfile##*/}
                echo "/etc/$i --> $cfgfile"
                break
            fi
        done
    
        if [ -z "$MOD_PATH" ]; then
            if [ -f /boot/grub2/grub.cfg ]; then
                PREFIX=/boot/grub2
                MOD_PATH=/boot/grub2
                CFG=grub.cfg 
                
                if [ -f /boot/efi/EFI/opensuse/grub.cfg ]; then
                    PREFIX=/EFI/opensuse
                fi                
            fi
            
            
        fi
    
        if [ -z "$MOD_PATH" ]; then
            echo "[WARNING] grub.cfg not found, this vhd/vdi/raw file can only be booted in UEFI mode."
            print_bios_grub_warning
            return
        fi
    fi

    if grub-mkimage -V > /dev/null 2>&1; then
        GRUB_CMD=grub-mkimage
        CFG_CMD=grub-mkconfig
    elif grub2-mkimage -V > /dev/null 2>&1; then
        GRUB_CMD=grub2-mkimage
        CFG_CMD=grub2-mkconfig
    else
        echo "[WARNING] grub-mkimage not found, package missing?"
        print_bios_grub_warning
        return
    fi

    if [ -d /usr/lib/grub/x86_64-efi ]; then
        GRUB_DIR=/usr/lib/grub
    elif [ -d /usr/lib/grub/i386-pc ]; then
        GRUB_DIR=/usr/lib/grub
    elif [ -d /usr/share/grub2/i386-pc ]; then
        GRUB_DIR=/usr/share/grub2
    else
        echo "[WARNING] grub module directory not found, package missing?"
        print_bios_grub_warning
        return
    fi

    if ! [ -d $GRUB_DIR/i386-pc ]; then
        echo "[WARNING] grub i386-pc modules not installed, package missing?"
        print_bios_grub_warning
        return
    fi

    if [ -e /dev/sda ]; then
        DISK=/dev/sda
    elif [ -e /dev/vda ]; then
        DISK=/dev/vda
    elif [ -e /dev/hda ]; then
        DISK=/dev/hda
    else
        echo "[WARNING] disk not found"
        print_bios_grub_warning
        return
    fi

    if $vtcheckcmd $DISK; then
        echo "GPT check $DISK OK ..."
    else
        echo "GPT check $DISK failed, code=$?"
        return 
    fi

    echo PREFIX=$PREFIX CFG=$CFG DISK=$DISK
    echo MOD_PATH=$MOD_PATH

    chkPrefix=$PREFIX
    while [ -n "$chkPrefix" ]; do
        if mountpoint -q "$chkPrefix"; then
            PREFIX=${MOD_PATH#$chkPrefix}
            echo "$chkPrefix is mountpoint PREFIX=$PREFIX"
            break
        fi
        chkPrefix=${chkPrefix%/*}
    done

    if grep -q 'linuxefi' $MOD_PATH/$CFG; then
        echo "update grub.cfg ..."
        cp -a ./tools/01_linuxefi /etc/grub.d/
        $CFG_CMD -o $MOD_PATH/$CFG
    elif grep -q 'blscfg' $MOD_PATH/$CFG; then
        echo "update grub.cfg disable bls ..."
        
        if grep -q '^GRUB_ENABLE_BLSCFG' /etc/default/grub; then        
            sed 's/^GRUB_ENABLE_BLSCFG.*/GRUB_ENABLE_BLSCFG=false/g'  -i /etc/default/grub
        else
            echo 'GRUB_ENABLE_BLSCFG=false' >> /etc/default/grub
        fi
        $CFG_CMD -o $MOD_PATH/$CFG
    fi

    cp -a ./tools/embedcfg  embed.cfg
    sed "s#XXX#$PREFIX#g" -i embed.cfg
    sed "s#YYY#$CFG#g" -i embed.cfg

    for mod in $(cat ./tools/grubmodules); do
        if [ -e $GRUB_DIR/i386-pc/${mod}.mod ]; then
            all_modules="$all_modules $mod"
        fi
    done

    $GRUB_CMD -c "./embed.cfg" --prefix "$PREFIX" --output "./core.img"  --format 'i386-pc' --compression 'auto'  $all_modules

    echo "Write loader to $DISK ..."
    dd if=$GRUB_DIR/i386-pc/boot.img of=$DISK bs=1 count=440 status=none && sync    
    dd if=./tools/bootbin of=/dev/sda bs=1 count=1 seek=92 status=none && sync
    dd if=./core.img of=/dev/sda bs=512 seek=34 status=none && sync
    dd if=./tools/bootbin of=/dev/sda bs=1 count=1 skip=1 seek=17908 status=none && sync
    
    if ! [ -d $MOD_PATH/i386-pc ]; then
        cp -a $GRUB_DIR/i386-pc $MOD_PATH/
    fi
    
    rm -f ./embed.cfg
    rm -f ./core.img
}

wrapper_grub_probe() {
    if [ -e "${1}-bk" ]; then
        if grep -q '#!' "$1"; then
            rm -f "$1"
            mv "${1}-bk" "$1"
        else
            rm -f "${1}-bk"
        fi
    fi

    cp -a "$1" "${1}-bk"
    rm -f "$1"
    cp -a ./tools/grub-probe.sh "$1"
    
    chmod +x "$1"
    chmod +x "${1}-bk"
}

replace_shim_efi() {
    echo "replace shim efi ..."
    if [ ! -d /boot/efi/EFI ]; then
        return
    fi
    
    vCnt=$(find /boot/efi/EFI -type f | grep -i /efi/boot/bootx64.efi | wc -l)
    if [ $vCnt -ne 1 ]; then
        echo "bootx64.efi no need $vCnt"
        return
    fi    
    vBOOTX64=$(find /boot/efi/EFI -type f | grep -i /efi/boot/bootx64.efi)
    
    vCnt=$(find /boot/efi/EFI -type f | grep -i shimx64.efi | wc -l)
    if [ $vCnt -ne 1 ]; then
        echo "shimx64.efi no need $vCnt"
        return
    fi    
    vSHIMX64=$(find /boot/efi/EFI -type f | grep -i shimx64.efi)
    
    vCnt=$(find /boot/efi/EFI -type f | grep -i grubx64.efi | wc -l)
    if [ $vCnt -ne 1 ]; then
        echo "grubx64.efi no need $vCnt"
        return
    fi    
    vGRUBX64=$(find /boot/efi/EFI -type f | grep -i grubx64.efi)
    
    vMD51=$(md5sum $vBOOTX64 | awk '{print $1}')
    vMD52=$(md5sum $vSHIMX64 | awk '{print $1}')
    if [ "$vMD51" != "$vMD52" ]; then
        echo "bootx64 shimx64 not equal"
        echo "$vMD51"
        echo "$vMD52"
        return
    fi
    
    echo "BOOT=$vBOOTX64"
    echo "GRUB=$vGRUBX64"
    mv $vBOOTX64 ${vBOOTX64}_VTBK
    cp $vGRUBX64 $vBOOTX64
}

recover_shim_efi() {
    echo "recover shim efi ..."
    if [ ! -d /boot/efi/EFI ]; then
        return
    fi
    
    vVTBKFILE=$(find /boot/efi/EFI -type f | grep -i '_VTBK$')
    if [ -z "$vVTBKFILE" ]; then
        echo "no backup file found, no need."
        return
    fi
    
    if [ -f "$vVTBKFILE" ]; then
        vVTRAWFILE=$(echo "$vVTBKFILE" | sed "s/_VTBK//")
        if [ -f "$vVTRAWFILE" ]; then
            rm -f "$vVTRAWFILE"
            echo "BACK=$vVTRAWFILE"
            echo "BOOT=$vVTBKFILE"
            mv "$vVTBKFILE" "$vVTRAWFILE"
        fi
    fi    
}
