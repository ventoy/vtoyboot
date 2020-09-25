#!/bin/sh

rm -f vtoyboot*.tar.gz

Ver=$(grep 'vtoy_version=' vtoyboot/vtoyboot.sh  | awk -F= '{print $2}')

cp -a vtoyboot vtoyboot-${Ver}

tar -cvf vtoyboot-${Ver}.tar.gz vtoyboot-${Ver}/

rm -rf vtoyboot-${Ver}

echo ""
echo "======== success ========"
echo ""
