
ventoy_check_efivars() {
    if [ -e /sys/firmware/efi ]; then
        if grep -q efivar /proc/mounts; then
            :
        else
            if [ -e /sys/firmware/efi/efivars ]; then
                mount -t efivarfs efivarfs /sys/firmware/efi/efivars  >/dev/null 2>&1
            fi
        fi
    fi
}

ventoy_log() {
    echo "$@" >> /tmp/vtoy.log
}

ventoy_need_dm_patch() {
    if vtoydump -R > /dev/null 2>&1; then
        [ 1 -eq 1 ]; return
    fi
    
    if grep -q "VTOY_LINUX_REMOUNT=1" /proc/cmdline; then
        [ 1 -eq 1 ]; return
    fi
    
    [ 1 -eq 0 ]
}

ventoy_check_insmod() {
    if [ -f /bin/kmod ]; then
        [ -f /bin/insmod ] || ln -s /bin/kmod /bin/insmod
        [ -f /bin/lsmod ]  || ln -s /bin/kmod /bin/lsmod
    fi
}

ventoy_do_dm_patch() {
    ventoy_log 'ventoy_do_dm_patch'

    if [ -f /bin/vtoydump ]; then
        vtHeadSize=$(stat -c '%s' /bin/vtoydump)
        dd if=/bin/vtoydmpatch of=/tmp/dm_patch.ko bs=1 skip=$vtHeadSize >/dev/null 2>&1
    elif [ -f /sbin/vtoydump ]; then
        vtHeadSize=$(stat -c '%s' /sbin/vtoydump)
        dd if=/sbin/vtoydmpatch of=/tmp/dm_patch.ko bs=1 skip=$vtHeadSize >/dev/null 2>&1
    else
        ventoy_log 'vtoydump not found'
        return
    fi
    
    if ! grep -m1 -q dm_get_table_device /proc/kallsyms; then
        ventoy_log "modprobe dm_mod"
        modprobe dm_mod >>/tmp/vtoy.log 2>&1
    fi
    
    cat /proc/kallsyms | sort > /tmp/kallsyms

    vtLine=$(vtoytool vtoyksym dm_get_table_device /tmp/kallsyms)
    get_addr=$(echo $vtLine | awk '{print $1}')
    get_size=$(echo $vtLine | awk '{print $2}')

    vtLine=$(vtoytool vtoyksym dm_put_table_device /tmp/kallsyms)
    put_addr=$(echo $vtLine | awk '{print $1}')
    put_size=$(echo $vtLine | awk '{print $2}')
    
    ro_addr=$(grep ' set_memory_ro$' /proc/kallsyms | awk '{print $1}')
    rw_addr=$(grep ' set_memory_rw$' /proc/kallsyms | awk '{print $1}')
    kprobe_reg_addr=$(grep ' register_kprobe$' /proc/kallsyms | awk '{print $1}')
    kprobe_unreg_addr=$(grep ' unregister_kprobe$' /proc/kallsyms | awk '{print $1}')
    
    if [ "$VTOY_DEBUG_LEVEL" = "01" ]; then
        printk_addr=$(grep ' printk$' /proc/kallsyms | awk '{print $1}')
        vtDebug="-v"
    else
        printk_addr=0
    fi
    
    #printk_addr=$(grep ' printk$' /proc/kallsyms | $AWK '{print $1}')
    #vtDebug="-v"

    ventoy_log get_addr=$get_addr  get_size=$get_size
    ventoy_log put_addr=$put_addr  put_size=$put_size
    ventoy_log kprobe_reg_addr=$kprobe_reg_addr  kprobe_unreg_addr=$kprobe_unreg_addr
    ventoy_log ro_addr=$ro_addr  rw_addr=$rw_addr  printk_addr=$printk_addr

    if [ "$get_addr" = "0" -o "$put_addr" = "0" ]; then
        ventoy_log "Invalid symbol address"
        return
    fi
    if [ "$ro_addr" = "0" -o "$rw_addr" = "0" ]; then
        ventoy_log "Invalid symbol address"
        return
    fi

    vtKv=$(uname -r)
    
    if [ ! -d /lib/modules/$vtKv ]; then
        ventoy_log "No modules directory found"
        return
    elif [ -d /lib/modules/$vtKv/kernel/fs ]; then
        vtModPath=$(find /lib/modules/$vtKv/kernel/fs/ -name "*.ko*" | head -n1)
    else
        vtModPath=$(find /lib/modules/$vtKv/kernel/ -name "xfs.ko*" | head -n1)
    fi
    
    if [ -z "$vtModPath" ]; then
        vtModPath=$(find /lib/modules/$vtKv/kernel/ -name "*.ko*" | head -n1)
    fi
    
    vtModName=$(basename $vtModPath)
    
    ventoy_log "template module is $vtModPath $vtModName"
    
    if [ -z "$vtModPath" ]; then
        ventoy_log "No template module found"
        return
    elif echo $vtModPath | grep -q "[.]ko$"; then
        cp -a $vtModPath  /tmp/$vtModName
    elif echo $vtModPath | grep -q "[.]ko[.]xz$"; then
        xzcat $vtModPath > /tmp/$vtModName
    elif echo $vtModPath | grep -q "[.]ko[.]gz$"; then
        zcat $vtModPath > /tmp/$vtModName
    else
        ventoy_log "unsupport module type"
        return
    fi
    
    #step1: modify vermagic/mod crc/relocation
    vtoytool vtoykmod -u /tmp/dm_patch.ko /tmp/$vtModName $vtDebug
    
    #step2: fill parameters
    vtPgsize=$(vtoytool vtoyksym -p)
    vtoytool vtoykmod -f /tmp/dm_patch.ko $vtPgsize 0x$printk_addr 0x$ro_addr 0x$rw_addr $get_addr $get_size $put_addr $put_size 0x$kprobe_reg_addr 0x$kprobe_unreg_addr $vtDebug

    ventoy_check_insmod
    insmod /tmp/dm_patch.ko
    
    if grep -q 'dm_patch' /proc/modules; then
        ventoy_log "dm_patch success"
    fi
}


ventoy_dm_patch_proc_begin() {
    if ventoy_need_dm_patch; then
        export vtLevel1=$(cat /proc/sys/kernel/printk | awk '{print $1}')
        export vtLevel2=$(cat /proc/sys/kernel/printk | awk '{print $2}')
        export vtLevel3=$(cat /proc/sys/kernel/printk | awk '{print $3}')
        export vtLevel4=$(cat /proc/sys/kernel/printk | awk '{print $4}')
        
        ventoy_do_dm_patch
        
        #suppress printk message
        echo 0 $vtLevel2 0 $vtLevel4 > /proc/sys/kernel/printk
    fi
}

ventoy_dm_patch_proc_end() {
    if ventoy_need_dm_patch; then    
        #recover printk level
        echo $vtLevel1 $vtLevel2 $vtLevel3 $vtLevel4 > /proc/sys/kernel/printk
    fi
}
