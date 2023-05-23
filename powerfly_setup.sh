#!/bin/bash

# Execute this script to setup new PowerFly.

# We need to run as root. Exit if script is not run as root.
if [[ $EUID > 0 ]] ; then 
    echo "Please run as root or use sudo "
    exit
fi


usage() {
   cat <<EOF
Usage: $0 [ -n name -p pw -r remoteit_key ]
where:
    -n --name                      powerfly docker image.
    -p --pw                        modbus-slave as a docker image.
    -r --remoteit_key              DER Controller.
EOF
   exit 0
}

name_entered=0
pw_entered=0
remoteit_key_entered=0

powerfly_name=""
powerfly_pw=""
remote_it_key=""

while [ "$1" != "" ]; do
    case $1 in
        -n | --name )           name_entered=1
                                shift
                                powerfly_name=$1
                                ;;
        -p | --pw )             pw_entered=1
                                shift
                                powerfly_pw=$1
                                ;;
        -r | --remoteit_key )   remoteit_key_entered=1
                                shift
                                remote_it_key=$1
                                ;;
        -h | --help )           usage
                                exit
                                ;;
        * )                     usage
                                exit 1
    esac
    shift
done

if [ $name_entered == 0 ] ; then
    echo "Enter the name for this powerfly"
    read powerfly_name
fi

if [ $pw_entered == 0 ] ; then
    echo "Enter the pw for $powerfly_name"
    read powerfly_pw
fi

if [ $remoteit_key_entered == 0 ] ; then
    echo "Enter the key for remote.it"
    read remote_it_key
fi

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
sudo hostnamectl set-hostname $powerfly_name

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