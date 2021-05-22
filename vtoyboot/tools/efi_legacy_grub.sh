#!/bin/sh

update_grub_config() {
    if update-grub -V > /dev/null 2>&1; then
        GRUB_UPDATE=update-grub
    elif update-grub2 -V > /dev/null 2>&1; then
        GRUB_UPDATE=update-grub2
    else
        echo "update-grub no need"
        return
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
    echo "[WARNING] ##################################################################"
    echo "[WARNING] #### This vhd/vdi/raw file will only be bootable in UEFI mode ####"
    echo "[WARNING] ##################################################################"
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
