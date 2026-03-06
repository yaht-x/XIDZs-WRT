#!/bin/sh

exec > "/root/setup-xidzswrt.log" 2>&1

echo "$(date)"

# Detect system type
echo "Checking system release..."
if grep -q "ImmortalWrt" /etc/openwrt_release; then
    sed -i 's/\(DISTRIB_DESCRIPTION='\''ImmortalWrt [0-9]*\.[0-9]*\.[0-9]*\).*'\''/\1'\''/g' /etc/openwrt_release
    echo "ImmortalWrt detected: $(grep 'DISTRIB_DESCRIPTION=' /etc/openwrt_release | awk -F"'" '{print $2}')"
elif grep -q "OpenWrt" /etc/openwrt_release; then
    sed -i 's/\(DISTRIB_DESCRIPTION='\''OpenWrt [0-9]*\.[0-9]*\.[0-9]*\).*'\''/\1'\''/g' /etc/openwrt_release
    echo "OpenWrt detected: $(grep 'DISTRIB_DESCRIPTION=' /etc/openwrt_release | awk -F"'" '{print $2}')"
else
    echo "Unknown system release"
fi

# package and add custom repo
echo "Disabling OPKG signature checking..."
sed -i 's/option check_signature/# option check_signature/g' /etc/opkg.conf

echo "Adding custom repository..."
echo "src/gz custom_packages https://dl.openwrt.ai/latest/packages/$(grep "OPENWRT_ARCH" /etc/os-release | awk -F '"' '{print $2}')/kiddin9" >> /etc/opkg/customfeeds.conf

# Basic system
echo "Setting root password..."
(echo "quenx"; sleep 1; echo "quenx") | passwd > /dev/null

echo "Configuring hostname and timezone..."
uci batch <<EOF
set system.@system[0].hostname='XIDZsWRT'
set system.@system[0].timezone='WIB-7'
set system.@system[0].zonename='Asia/Jakarta'
delete system.ntp.server
add_list system.ntp.server='pool.ntp.org'
add_list system.ntp.server='id.pool.ntp.org'
add_list system.ntp.server='time.google.com'
commit system
EOF

# language and theme
echo "Setting default en language and theme argon..."
uci batch <<EOF
set luci.@core[0].lang='en'
set luci.main.mediaurlbase='/luci-static/argon'
commit luci
EOF

# network interface
echo "Configuring network interfaces..."
uci batch <<EOF
set network.wan=interface
set network.wan.proto='dhcp'
set network.wan.device='eth1'
set network.tethering=interface
set network.tethering.proto='dhcp'
set network.tethering.device='usb0'
delete network.wan6
commit network
EOF

# firewall
echo "Configuring firewall..."
uci batch <<EOF
set firewall.@zone[1].network='tethering wan'
commit firewall
EOF

# me909s and dw5821e
echo "Removing USB modeswitch entries..."
sed -i -e '/12d1:15c1/,+5d' -e '/413c:81d7/,+5d' /etc/usb-mode.json

# xmm-modem
echo "Disabling XMM-Modem and TTYD..."
uci batch <<EOF
set xmm-modem.@xmm-modem[0].enable='0'
set ttyd.@ttyd[0].command='/bin/bash --login'
commit xmm-modem
commit ttyd
EOF

# tinyfm
echo "Setting up TinyFM..."
ln -sf / /www/tinyfm/rootfs

# System customizations
echo "Applying system.."
sed -i -e 's/\[ -f \/etc\/banner \] && cat \/etc\/banner/#&/' -e 's/\[ -n \"\$FAILSAFE\" \] && cat \/etc\/banner.failsafe/& || \/usr\/bin\/syntax/' /etc/profile

# UI customizations
echo "Modifying UI elements..."
sed -i "s#_('Firmware Version'),(L.isObject(boardinfo.release)?boardinfo.release.description+' / ':'')+(luciversion||''),#_('Firmware Version'),(L.isObject(boardinfo.release)?boardinfo.release.description+' | xidz_x':''),#g" /www/luci-static/resources/view/status/include/10_system.js
sed -i -E 's/icons\/port_%s\.(svg|png)/icons\/port_%s.gif/g' /www/luci-static/resources/view/status/include/29_ports.js
mv /www/luci-static/resources/view/status/include/29_ports.js /www/luci-static/resources/view/status/include/11_ports.js

# Tunnel
# Web server
echo "Configuring web server and PHP..."
uci batch <<EOF
set uhttpd.main.ubus_prefix='/ubus'
set uhttpd.main.interpreter='.php=/usr/bin/php-cgi'
set uhttpd.main.index_page='cgi-bin/luci'
add_list uhttpd.main.index_page='index.html'
add_list uhttpd.main.index_page='index.php'
commit uhttpd
EOF

# php8
cp /etc/php.ini /etc/php.ini.bak
sed -i 's|^memory_limit = .*|memory_limit = 128M|g' /etc/php.ini
sed -i 's|^max_execution_time = .*|max_execution_time = 60|g' /etc/php.ini
sed -i 's|^display_errors = .*|display_errors = Off|g' /etc/php.ini
sed -i 's|^;*date\.timezone =.*|date.timezone = Asia/Jakarta|g' /etc/php.ini
ln -sf /usr/lib/php8 /usr/lib/php

exit 0