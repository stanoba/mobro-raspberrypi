#!/bin/bash

# intro message like "youre about to install the modbros monitoring service"

if [[ $EUID -ne 0 ]]; then
   echo "This script requires root privileges"
   echo "Please run again as 'sudo ./install.sh'"
   exit 1
fi

# TODO intro
echo "On a Raspberry Pi 3 with a clean install of 'Raspian Stretch with desktop'
(excluding the recommended software) this will take up to about TODO minutes."


# =============================
# update & install dependencies
# =============================

echo "Updating your Raspberry..."
apt-get update && apt-get upgrade -y

echo "Installing necessary libraries..."
apt-get install apache2 php7.0 libapache2-mod-php7.0 -y
apt-get install chromium-browser -y
apt-get install hostapd dnsmasq -y
apt-get install unclutter -y


# =============================
# Stop and disable access point services
# =============================

systemctl stop dnsmasq
systemctl stop hostapd

systemctl disable dnsmasq.service
systemctl disable hostapd.service


# =============================
# copy Web
# =============================

echo "Copying web resources..."
rm -rf /var/www/html/modbros/*

if [[ ! -d /var/www/html/modbros ]]; then
    mkdir /var/www/html/modbros
fi

chmod +rx ./Web/favicon.ico
cp -rf ./Web/* /var/www/html/modbros/

echo "restarting web server..."
service apache2 restart


# =============================
# backup original config files
# =============================

echo "backup up original configuration files..."

if [[ ! -f /etc/dhcpcd.conf.orig ]]; then
    cp /etc/dhcpcd.conf /etc/dhcpcd.conf.orig
fi

if [[ ! -f /etc/wpa_supplicant/wpa_supplicant.conf.orig ]]; then
    cp /etc/wpa_supplicant/wpa_supplicant.conf /etc/wpa_supplicant/wpa_supplicant.conf.orig
fi

if [[ ! -f /etc/dnsmasq.conf.orig ]]; then
    cp /etc/dnsmasq.conf /etc/dnsmasq.conf.orig
fi

if [[ ! -f /etc/default/hostapd.orig ]]; then
    cp /etc/default/hostapd /etc/default/hostapd.orig
fi


# =============================
# Configure DHCP (dnsmasq)
# =============================

echo "Configuring the DHCP server (dnsmasq)..."
cp ./Config/dnsmasq.conf /etc/dnsmasq.conf


# =============================
# Configure access point (hostapd)
# =============================

echo "Configuring the access point host software (hostapd)..."

cp ./Config/hostapd.conf /etc/hostapd/hostapd.conf
sed -i -e "s/#DAEMON_CONF=\"\"/DAEMON_CONF=\"\/etc\/hostapd\/hostapd.conf\"/g" /etc/default/hostapd


# =============================
# Set script permissions
# =============================

echo "Setting script permissions..."

chmod +x ./*.sh
chmod +x ./Service/modbros.sh
chmod 644 ./Service/modbros.service


# =============================
# Set custom wallpaper
# =============================

echo "Setting custom ModBros wallpaper..."

pcmanfm --set-wallpaper $(pwd)/Resources/modbros_wallpaper.png


# =============================
# Scan for available networks
# =============================

echo "Scanning for available networks..."

iwlist wlan0 scan | grep -i essid: | sed 's/^.*"\(.*\)"$/\1/' > /var/www/html/modbros/networks


# =============================
# Setting user permissions
# =============================

cp -f ./Config/010_wwwdata-wifi /etc/sudoers.d

chmod 0440 /etc/sudoers.d/010_wwwdata-wifi


# =============================
# Service
# =============================

echo "installing ModBros service"

cp ./Service/modbros.service /lib/systemd/system/modbros.service
systemctl daemon-reload
systemctl enable modbros.service
systemctl start modbros.service


# =============================
# Reboot
# =============================

echo "Done. Rebooting..."

reboot

exit 0