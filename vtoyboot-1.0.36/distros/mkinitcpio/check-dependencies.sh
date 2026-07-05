#!/bin/bash
# Dependency checker for Ventoy mkinitcpio systemd support

echo "=== Checking Dependencies for Ventoy mkinitcpio systemd support ==="
echo ""

missing=0

# Check required packages
echo "Checking required packages:"

if pacman -Q lvm2 >/dev/null 2>&1; then
    echo "  ✓ lvm2 (provides dmsetup)"
else
    echo "  ✗ lvm2 - MISSING (provides dmsetup)"
    echo "    Install: sudo pacman -S lvm2"
    missing=1
fi

# Check for awk (multiple providers)
if command -v awk >/dev/null 2>&1; then
    awk_provider=$(pacman -Qo $(which awk) 2>/dev/null | awk '{print $5}')
    echo "  ✓ awk (provided by $awk_provider)"
else
    echo "  ✗ awk - MISSING"
    echo "    Install: sudo pacman -S gawk (or busybox)"
    missing=1
fi

if command -v grep >/dev/null 2>&1; then
    echo "  ✓ grep"
else
    echo "  ✗ grep - MISSING"
    echo "    Install: sudo pacman -S grep"
    missing=1
fi

echo ""
echo "Checking required binaries in PATH:"

for binary in dmsetup vtoydump vtoypartx vtoytool awk grep which; do
    if command -v $binary >/dev/null 2>&1; then
        echo "  ✓ $binary: $(which $binary)"
    else
        echo "  ✗ $binary - NOT FOUND"
        missing=1
    fi
done

echo ""
echo "Checking systemd files:"

if [ -f /usr/lib/initcpio/install/ventoy ]; then
    echo "  ✓ /usr/lib/initcpio/install/ventoy"
else
    echo "  ✗ /usr/lib/initcpio/install/ventoy - NOT FOUND"
fi

if [ -f /usr/lib/initcpio/hooks/ventoy ]; then
    echo "  ✓ /usr/lib/initcpio/hooks/ventoy"
else
    echo "  ✗ /usr/lib/initcpio/hooks/ventoy - NOT FOUND"
fi

if [ -f /usr/lib/initcpio/ventoy-device-mapper ]; then
    echo "  ✓ /usr/lib/initcpio/ventoy-device-mapper"
    if [ -x /usr/lib/initcpio/ventoy-device-mapper ]; then
        echo "    ✓ Executable"
    else
        echo "    ✗ Not executable (should be 755)"
    fi
else
    echo "  ✗ /usr/lib/initcpio/ventoy-device-mapper - NOT FOUND"
fi

if [ -f /usr/lib/systemd/system/ventoy-device-mapper.service ]; then
    echo "  ✓ /usr/lib/systemd/system/ventoy-device-mapper.service"
else
    echo "  ✗ /usr/lib/systemd/system/ventoy-device-mapper.service - NOT FOUND"
fi

echo ""
if [ $missing -eq 0 ]; then
    echo "✅ All dependencies satisfied"
	[ -n "1" ]
else
    echo "❌ Some dependencies are missing"
    echo ""
    echo "To install missing dependencies:"
    echo "  sudo pacman -S lvm2 gawk grep"
    exit 1
fi
