#!/bin/bash

# Execute this script to setup new PowerFly.

# We need to run as root. Exit if script is not run as root.
if [[ $EUID > 0 ]] ; then 
    echo "Please run as root or use sudo "
    exit
fi

echo "Enter the name for this powerfly"
read powerfly_name

echo "Enter the pw for $powerfly_name"
read powerfly_pw

echo "Enter the key for remote.it"
read remote_it_key

echo Update and Upgrade
sudo apt update && sudo apt upgrade -y

# 3) disable teamviewer
echo "********************************************** Disabling team_viewer"
sudo systemctl disable teamviewer-iot-mon-agent.service

# 4) change pw
echo "********************************************** Changing pw"
echo pi:$powerfly_pw | chpasswd

# 5) change host name
echo "********************************************** Changing host name"
sudo raspi-config nonint do_hostname $powerfly_name

# 6) Localization a) Change locale en_US.UTF-8 UTF-8
echo "********************************************** Changing Locale"
sudo raspi-config nonint do_configure_keyboard us
sudo raspi-config nonint do_change_locale LANG=en_US.UTF-8

# 6) Localization b) Timezone “US” as the “Geographic area”.  For California use “Pacific Ocean”
echo "********************************************** Changing Timezone"
sudo raspi-config nonint do_change_timezone US/Pacific

# 7) install remote.it
echo "********************************************** Installing remote.it"
cd ~
R3_REGISTRATION_CODE="$remote_it_key" sh -c "$(curl -L https://downloads.remote.it/remoteit/install_agent.sh)"

# 7) install docker
echo "********************************************** Installing docker"
curl -sSL https://get.docker.com | sh
sudo usermod -aG docker pi


echo "********************************************** Rebooting $powerfly_name"
sudo reboot