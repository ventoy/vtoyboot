#!/bin/sh

if which grub-probe-bk >/dev/null 2>&1; then
    grub_probe_cmd=grub-probe-bk
elif which grub2-probe-bk >/dev/null 2>&1; then
    grub_probe_cmd=grub2-probe-bk
else
    grub_probe_cmd=grub-probe-bk
fi

curdate=$(date)
if [ -e /dev/mapper/ventoy -a -d /etc/vtoyboot/probe ]; then
    $grub_probe_cmd $* > /etc/vtoyboot/probe/tmp_stdout 2>/etc/vtoyboot/probe/tmp_stderr
    code=$?
    if [ $code -eq 0 ]; then
        cat /etc/vtoyboot/probe/tmp_stdout
        exit 0
    fi

    newpara=$(echo $* | sed "s#/dev/mapper/ventoy#/dev/sda#")
    echo "[$curdate] oldpara=$* newpara=$newpara" >> /etc/vtoyboot/probe/match.log

    id=1
    while [ -n "1" ]; do
        if [ -d /etc/vtoyboot/probe/$id ]; then
            para=$(head -n1 /etc/vtoyboot/probe/$id/param)
            if [ "$para" = "$newpara" ]; then
                code=$(cat /etc/vtoyboot/probe/$id/errcode)
                cat /etc/vtoyboot/probe/$id/stdout
                if [ $code -ne 0 ]; then
                    cat /etc/vtoyboot/probe/$id/stderr >&2
                fi
                
                echo "[$curdate] grub-probe match history id=$id code=$code" >> /etc/vtoyboot/probe/match.log
                exit $code
            fi
        else
            break
        fi
        id=$(expr $id + 1)
    done

    echo "[$curdate] grub-probe NO match $*" >> /etc/vtoyboot/probe/match.log
    cat /etc/vtoyboot/probe/tmp_stdout
    cat /etc/vtoyboot/probe/tmp_stderr >&2
    exit $code
else
    [ -d /etc/vtoyboot/probe ] || mkdir -p /etc/vtoyboot/probe
    
    id=1
    override=0
    while [ -d /etc/vtoyboot/probe/$id ]; do
        para=$(head -n1 /etc/vtoyboot/probe/$id/param)
        if [ "$para" = "$*" ]; then
            echo "[$curdate] override $id $*" >> /etc/vtoyboot/probe/history.log
            override=1
            break
        fi
        id=$(expr $id + 1)
    done

    if [ $override -eq 0 ]; then
        echo "[$curdate] $*" >> /etc/vtoyboot/probe/history.log
    fi

    mkdir -p /etc/vtoyboot/probe/$id
    echo "$*" > /etc/vtoyboot/probe/$id/param
    $grub_probe_cmd $* > /etc/vtoyboot/probe/$id/stdout 2>/etc/vtoyboot/probe/$id/stderr
    code=$?
    echo $code > /etc/vtoyboot/probe/$id/errcode
    
    cat /etc/vtoyboot/probe/$id/stdout
    cat /etc/vtoyboot/probe/$id/stderr >&2
    exit $code
fi

