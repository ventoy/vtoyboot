#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh

check() {
    require_binaries sed grep awk || return 1
    return 255
}

depends() {
    echo dm
    return 0
}


install() {
    inst_multiple sed grep awk dd sort head find basename xzcat zcat vtoydump vtoypartx vtoydmpatch vtoytool
    inst_hook initqueue/settled 99 "$moddir/ventoy-settled.sh"
    dracut_need_initqueue
}
