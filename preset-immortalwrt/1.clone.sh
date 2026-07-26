#!/usr/bin/env bash

# download base code
CODE_DIR=_firmware_code
CODE_URL=https://github.com/immortalwrt/immortalwrt.git
CODE_BRANCH=openwrt-24.10
SWITCH_LATEST_TAG=false
git clone --single-branch -b $CODE_BRANCH $CODE_URL $CODE_DIR
if $SWITCH_LATEST_TAG; then
    cd $CODE_DIR
    LATEST_TAG_HASH=$(git rev-list --tags --max-count=1)
    if [ -z "$LATEST_TAG_HASH" ]; then
        echo "No tag to switch, keep the latest commit"
    else
        git checkout $LATEST_TAG_HASH
        LATEST_TAG=$(git describe --tags $LATEST_TAG_HASH)
        echo "The code has been switched to the latest stable version $LATEST_TAG"
    fi
    cd ..
fi
mv ./$CODE_DIR/* ./

# download app codes
SUPPLY_DIR=_supply_packages
echo "src-link supply $PWD/$SUPPLY_DIR" >> feeds.conf.default
mkdir $SUPPLY_DIR && cd $SUPPLY_DIR
git clone --depth 1 https://github.com/jerrykuku/luci-theme-argon.git
git clone --depth 1 https://github.com/jerrykuku/luci-app-argon-config.git
#git clone --depth 1 https://github.com/xiaorouji/openwrt-passwall-packages.git pw-dependencies
#git clone --depth 1 https://github.com/xiaorouji/openwrt-passwall.git && mv openwrt-passwall/luci-app-passwall ./ && rm -rf openwrt-passwall
#git clone --depth 1 https://github.com/xiaorouji/openwrt-passwall2.git && mv openwrt-passwall2/luci-app-passwall2 ./ && rm -rf openwrt-passwall2
cd ..

# download UA3F
git clone --depth 1 https://github.com/SunBK201/UA3F.git package/UA3F
echo 'include ./openwrt/Makefile' > package/UA3F/Makefile
# remove iptables dependencies (SOCKS5/HTTP mode only)
sed -i 's/+luci-compat +ipset +iptables.*+kmod-nf-conntrack-netlink/+luci-compat/' package/UA3F/openwrt/Makefile

# pre-place ShellCrash into firmware
SHELLCRASH_URL="https://testingcf.jsdelivr.net/gh/juewuy/ShellCrash@master"
mkdir -p files/etc/ShellCrash
wget -q --no-check-certificate -O /tmp/ShellCrash.tar.gz "$SHELLCRASH_URL/ShellCrash.tar.gz"
tar -zxf /tmp/ShellCrash.tar.gz -C files/etc/ShellCrash/
rm -f /tmp/ShellCrash.tar.gz

# create crash command wrapper
mkdir -p files/usr/bin
cat > files/usr/bin/crash << 'CRASH_EOF'
#!/bin/sh
exec sh /etc/ShellCrash/menu.sh "$@"
CRASH_EOF
chmod +x files/usr/bin/crash

# first-boot init for ShellCrash
mkdir -p files/etc/uci-defaults
cat > files/etc/uci-defaults/99-shellcrash-init << 'INIT_EOF'
#!/bin/sh
[ -f /etc/ShellCrash/init.sh ] && sh /etc/ShellCrash/init.sh
exit 0
INIT_EOF
chmod +x files/etc/uci-defaults/99-shellcrash-init
