#!/bin/sh

rm -f vtoyboot*.tar.gz
rm -f vtoyboot*.iso

Ver=$(grep 'vtoy_version=' vtoyboot/vtoyboot.sh  | awk -F= '{print $2}')

cp -a vtoyboot vtoyboot-${Ver}

sed -i "/AUTO_INSERT_COMMON_FUNC/ r commonfunc.sh" vtoyboot-${Ver}/distros/dracut/ventoy-settled.sh
sed -i "/AUTO_INSERT_COMMON_FUNC/ r commonfunc.sh" vtoyboot-${Ver}/distros/initramfstool/vtoy-local-top.sh
sed -i "/AUTO_INSERT_COMMON_FUNC/ r commonfunc.sh" vtoyboot-${Ver}/distros/mkinitcpio/ventoy-hook.sh


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

