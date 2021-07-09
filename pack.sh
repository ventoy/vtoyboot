#!/bin/sh

rm -f vtoyboot*.tar.gz
rm -f vtoyboot*.iso

Ver=$(grep 'vtoy_version=' vtoyboot/vtoyboot.sh  | awk -F= '{print $2}')

cp -a vtoyboot vtoyboot-${Ver}

tar -czvf vtoyboot-${Ver}.tar.gz vtoyboot-${Ver}/

rm -rf vtoyboot-${Ver}

mkdir tmpiso
cp -a vtoyboot-${Ver}.tar.gz tmpiso/
cd tmpiso
xorriso -as mkisofs  -allow-lowercase  -v -R -J -V  'Vtoyboot' -P 'VENTOY' -p 'https://www.ventoy.net'  -o ../vtoyboot-${Ver}.iso .
cd ..
rm -rf tmpiso

sha256sum vtoyboot-${Ver}.iso

echo ""
echo "======== success ========"
echo ""

