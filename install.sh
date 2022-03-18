#!/bin/bash

# Execute this script to add PowerFly application to  Raspberrypi startup code.

# We need cron job to run as root. Exit if script is not run as root.
if [[ $EUID > 0 ]] ; then 
    echo "Please run as root or use sudo "
    exit
fi
command_args=$@

# Add connectd_start_all to cron jobs for root user
command="/usr/bin/connectd_start_all"
job="*/5 * * * * $command # check once, every 5 minutes"
# Following line adds the $command to crontab only if it is absent in (crontab -l).
cat <(fgrep -i -v "$command" <(crontab -l)) <(echo "$job") | crontab -

# Colours
YELLOW='\033[1;33m'
RED='\033[0;31m'
SET='\033[0m'

LOG_FILE="installer.log"

required_files=("config.json" 
"connection.json" 
"force-shutdown" 
"roots.pem" 
"rsa-cert.pem" 
"rsa-private.pem" 
)

project=$(grep '"project"' connection.json|cut -f2 -d":"|tr -d '",')
device_registry=$(grep '"registry"' connection.json|cut -f2 -d":"|tr -d '",')
device_id=$(grep '"device"' connection.json|cut -f2 -d":"|tr -d '",')
registry="us.gcr.io/"$project/

log_installer_data ()
{
    echo $@ >> $LOG_FILE
}

log_docker_info ()
{
    cmd="docker images --digests"
    log_installer_data ========  $cmd $@
    $cmd >> $LOG_FILE
    cmd="docker ps -a"
    log_installer_data ========  $cmd $@
    $cmd >> $LOG_FILE

    log_installer_data ========  docker container details
    cmd="docker ps -a -q"
    containers=$($cmd)
    for container in $containers
    do
        cmd="docker inspect $container | grep Image"
        eval docker_image_info=\`${cmd}\`
        echo $docker_image_info >> $LOG_FILE
        cmd="docker inspect $container | grep Labels -A 5"
        eval docker_ver_info=\`${cmd}\`
        echo $docker_ver_info >> $LOG_FILE
    done

    if [ -f "logging.txt" ]; then
        log_installer_data "========  Powerfly startup log (from log file)"
        grep Powerfly logging.txt >> $LOG_FILE
        log_installer_data "========  Powerfly latest startup time (from log file)"
        grep Powerfly logging.txt |tail -1 >> $LOG_FILE
    else 
        echo "New installation." >> $LOG_FILE
    fi
}

######### watchdog
is_watchdog_in_boot_config ()
{
    if [ -f "/boot/config.txt" ]; then
    cmd="grep dtparam=watchdog=on /boot/config.txt -c"
    watchdog_enabled=$($cmd)
    if [ $watchdog_enabled == 0 ]; then
        return 0
    fi
    return 1  
    else
        return 0
    fi
}

add_watchdog_to_boot_config ()
{
    echo 'dtparam=watchdog=on' >> /boot/config.txt
}

is_watchdog_dev_present ()
{
    CHAR_FILE=/dev/watchdog

    if test -c $CHAR_FILE; then
        return 1  
    fi
    return 0
}

is_watchdog_installed ()
{
    if [ -x "$(command -v watchdog)" ]; then
        return 1  
    fi
    return 0
}

install_watchdog ()
{
    #apt update
    apt install watchdog
}

is_watchdog_configured ()
{
    cmd="grep PowerFly /etc/watchdog.conf -c"
    watchdog_configured=$($cmd)
    if [ $watchdog_configured == 0 ]; then
        return 0
    fi
    return 1  
}

update_watchdog_config ()
{
    powerfly_log=$('pwd')/logging.txt
    sed -i 's@file = [a-zA-Z0-9_./-]*@file = '$powerfly_log'@' /etc/watchdog.conf
}

add_watchdog_config ()
{
    echo '#Watchdog Config for PowerFly' >> /etc/watchdog.conf
    update_watchdog_config
    echo 'watchdog-timeout = 60' >> /etc/watchdog.conf
    echo 'max-load-1 = 24' >> /etc/watchdog.conf
    echo 'file = '$powerfly_log  >> /etc/watchdog.conf
    echo 'change = 60'  >> /etc/watchdog.conf
}

wd_status='cmd="sudo systemctl is-active watchdog"
    service_state=$($cmd)
    if [ $service_state == "active" ]; then
        return 1 ;
    fi
    return 0
'
is_watchdog_service_enabled()
{
    eval "$wd_status"
}

#is_watchdog_service_enabled

wd_enable='is_watchdog_service_enabled
    watchdog_service_state=$?
    if [ $watchdog_service_state == 0 ]; then
        #echo "Starting watchdog service"
        sudo systemctl enable watchdog
        sudo systemctl start watchdog
        sudo systemctl status --no-pager watchdog --lines=0
        is_watchdog_service_enabled
        watchdog_service_state=$?
        if [ $watchdog_service_state == 0 ]; then
                echo "Error: Unable to start watchdog service"
        fi
    fi
'
enable_watchdog_service()
{
    eval "$wd_enable"
}

wd_disable='is_watchdog_service_enabled
    watchdog_service_state=$?
    if [ $watchdog_service_state == 1 ]; then
        #echo "Stopping watchdog service"
        sudo systemctl disable watchdog
        sudo systemctl stop watchdog
        sudo systemctl status --no-pager watchdog --lines=0
        is_watchdog_service_enabled
        watchdog_service_state=$?
        if [ $watchdog_service_state == 1 ]; then
                echo "Error: Unable to stop watchdog service"
        fi
    fi
'
disable_watchdog_service()
{
   eval "$wd_disable"
}

watchdog_init ()
{
    is_watchdog_dev_present
    watchdog_dev_presence=$?
    if [ $watchdog_dev_presence == 1 ]; then
        is_watchdog_installed
        installed_status=$?
        if [ $installed_status == 1 ]; then
            #echo "Watchdog installed and ready"
            is_watchdog_configured
            config_status=$?
            if [ $config_status == 0 ]; then
                #echo "Watchdog config being added"
                add_watchdog_config
                is_watchdog_configured
                config_status=$?
                if [ $config_status == 0 ]; then
                    echo "Error: Watchdog Config Add Failed"
                fi           
            else
                #echo "Watchdog config being updated"
                update_watchdog_config
            fi

        else
            echo "Install watchdog"
            install_watchdog
            is_watchdog_installed
            installed_status=$?
            if [ $installed_status == 1 ]; then
                #echo "Watchdog installed and ready"
                is_watchdog_configured
                config_status=$?
                if [ $config_status == 0 ]; then
                    #echo "Watchdog config being added"
                    add_watchdog_config
                    is_watchdog_configured
                    config_status=$?
                    if [ $config_status == 0 ]; then
                        echo "Error: Watchdog Config Add Failed"
                    fi              
                else
                    #echo "Watchdog config being updated"
                    update_watchdog_config
                fi
            else
                echo "Error: Watchdog installation failed."
            fi

        fi
    else
        is_watchdog_in_boot_config
        boot_config_watchdog_presence=$?
        #echo boot_config_watchdog_presence is $boot_config_watchdog_presence
        if [ $boot_config_watchdog_presence == 0 ]; then
            echo "Enable Watchdog in /boot/config.txt"
            add_watchdog_to_boot_config
            boot_config_watchdog_presence=$?
            if [ $boot_config_watchdog_presence == 1 ]; then
                echo "Reboot in 5 seconds"
                sleep 5
                echo "Reboot"
                reboot
            else
                echo "Error:Unable to update boot file"
            fi
        else
            echo "Error: Boot file already contains changes. Try manual reboot"
        fi
    fi
}

do_exit()
{
    log_docker_info end
    cmd="date"
    data=$($cmd)
    log_installer_data ==================================  Session End [$data]
    printf "\n" >> $LOG_FILE
    echo
    Info "source $alias_file to get alias helpers"
    echo
    exit $@
}
### Error($1:Msg)
Error ()
{
    echo -e "${RED}$@${SET}"
    log_installer_data Error: $@
}

Info ()
{
    echo -e "${YELLOW}$@${SET}"
    log_installer_data Info: $@
}

# script can be only executed from

if [ "$OSTYPE" != "linux-gnueabihf" ] && [ "$OSTYPE" != "linux-gnu" ]; then
   Error "This script runs only on Linux flavours. Found [$OSTYPE]"
   do_exit -1
fi

# Check file_list
for file_name in "${required_files[@]}"; do
    if [ ! -f "$file_name" ]; then
        Error "Error: Missing $file_name."
        echo "Make sure you are in the right Directory."
        do_exit -1
    fi
done

do_entry()
{
    #log_installer_data begin
    printf "\n" >> $LOG_FILE
    log_installer_data
    cmd="date"
    data=$($cmd)
    log_installer_data ==================================  Session Begin [$data]
    #log_installer_data "Date            : $data"
    Info "OS              : $OSTYPE"
    Info "Gateway device  : $device_id"
    Info "Device registry : $device_registry"
    Info "Image registry  : $registry"

    log_docker_info begin
    log_installer_data ========  Command
    log_installer_data  $0 $command_args
    #log_installer_data complete
}

do_entry

update_dhcpcd_conf ()
{
    #take backup of /etc/dhcpcd.conf
    #add "denyinterface wwan0" to /etc/dhcpcd.conf

    if [ "$OSTYPE" == "linux-gnueabihf" ]
    then
        #echo denyinterfaces wwan0
        file="dhcpcd.conf"
        file_bk="dhcpcd_bk.conf"
        folder="/etc/"
        filename=$folder$file
        filename_bk=$folder$file_bk

        if grep -s -q "denyinterfaces wwan0" $filename
        then
            echo ""
            log_installer_data $filename contains "denyinterfaces wwan0"
        elif test -f $filename
        then
            sudo cp $filename $filename_bk
            echo "" >> $filename
            echo "denyinterfaces wwan0" >> $filename
            log_installer_data "denyinterfaces wwan0" added to $filename
        else
            echo ""
            log_installer_data $filename not found.
        fi
    fi
}

#initialize watchdog
watchdog_init

### Add aliases ################################
alias_file=./.aliases_power

### powerfly
service=powerfly
c=p
wdstatus='is_watchdog_service_enabled() { '$wd_status' }'
wdstart='enable_watchdog() { '$wd_enable' }'
wdstop='disable_watchdog() { '$wd_disable' }'
pstatus=$c'status() { sudo docker ps -a -f name='$service'-$1; }'
pstart=$c'start() { sudo docker start '$service'-$1; 
    error=$?
    if [ $error == 0 ]; then
        enable_watchdog
    fi
}'
pstop=$c'stop() { sudo docker stop '$service'-$1; 
    error=$?
    if [ $error == 0 ]; then
        disable_watchdog
    fi
}'
pcat=$c'cat() { sudo docker logs '$service'-$1; }'
pcatf=$c'catf() { sudo docker logs -f '$service'-$1; }'
pps=$c'ps() { sudo docker ps -a -f name='$service'-$1; }'


### modbus-slave
service=modbus-slave
c=m
mstatus=$c'status() { sudo docker ps -a -f name='$service'-$1; }'
mstart=$c'start() { sudo docker start '$service'-$1; }'
mstop=$c'stop() { sudo docker stop '$service'-$1; }'
mcat=$c'cat() { sudo docker logs '$service'-$1; }'
mcatf=$c'catf() { sudo docker logs -f '$service'-$1; }'
mps=$c'ps() { sudo docker ps -a -f name='$service'-$1; }'

#  add it .bash_aliases file
rm -f $alias_file
echo "$wdstatus" >> $alias_file
echo "$wdstart" >> $alias_file
echo "$wdstop" >> $alias_file
unset -f $pstatus &&  echo "$pstatus" >> $alias_file
unset -f $pstart  &&  echo "$pstart"  >> $alias_file
unset -f $pstop   &&  echo "$pstop"   >> $alias_file
unset -f $pcat    &&  echo "$pcat"    >> $alias_file
unset -f $pcatf   &&  echo "$pcatf"   >> $alias_file
unset -f $pps     &&  echo "$pps"     >> $alias_file

unset -f $mstatus &&  echo "$mstatus" >> $alias_file
unset -f $mstart  &&  echo "$mstart"  >> $alias_file
unset -f $mstop   &&  echo "$mstop"   >> $alias_file
unset -f $mcat    &&  echo "$mcat"    >> $alias_file
unset -f $mcatf   &&  echo "$mcatf"   >> $alias_file
unset -f $mps     &&  echo "$mps"     >> $alias_file

### Set the variables
service_dir=/lib/systemd/system
base_name=`basename $0`
base_path=$(dirname $(readlink -f $0))
install_path="$base_path"
powerfly_service_name='powerfly'
modbus_service_name='modbus-slave'
ip=$(hostname -I | sed 's/ .*//')
from_port=1500
parameters=()
local_docker=0

### Usage
usage() {
   cat <<EOF
Usage: $0 -p | -m dev [-i ins [-l] [-v v] [-t p] ] | -u | -s]
where:
    -p --powerfly                            powerfly service
    -m --modbus [inverter|carboncap|pb_carboncap|meter|acuvim|c2_acuvim|l-acuvim|
                 solectria|hawk-1000|delta-M80|delta-PCS125kW|hiq-solar|
                 conext_gw_502|conext_xw_502|conext_gw_503|conext_xw_503|
                 delta_essbd|sebms2|acurev_2100|delta_PCSBMS125|delta_PCS125|
                 BACNetServerSim]
                                             modbus-slave service
    -e --interval                            Interval in HH:MM:SS (Hours:Minutes:Seconds)
    -l --local                               install from local docker(tar) image
    -i --install instances                   number of instances to install
    -v --version version                     version to install
    -t --port                                starting port number for the service
    -u --uninstall                           uninstalls
    -s --status                              status of a service
EOF
   do_exit 0
}
docker_refresh_image=''
private_json="rsa-private.json"

# add auto upgrade_cronjob 
add_auto_upgrade_cronjob(){
    powerfly_refresh_file=/usr/bin/powerfly_refresh
    powerfly_refresh_list_file=/usr/bin/powerfly_refresh_list
    folder_name=$("pwd")
    # add folder name to the powerfly_refresh_list file.
    grep -qsF -- $folder_name $powerfly_refresh_list_file || echo $folder_name >> $powerfly_refresh_list_file
    powerfly_refresh_file_content='#!/bin/bash
    pull_image() {
        cd '$("pwd")'
        cmd="docker login -u _json_key --password-stdin https://us.gcr.io < '$private_json'"
        #echo $cmd
        eval $cmd
        cmd="docker pull "'$docker_refresh_image'
        #echo cmd is [$cmd]
        status=$($cmd)
        cmd="docker logout https://us.gcr.io"
        #echo $cmd
        $cmd
        echo status is $status

        new_image="Downloaded newer image"
        if [[ "$status" == *"$new_image"* ]]; then
            echo "Image updated. Running install.sh in all powerfly folders"            
            while IFS= read -r line
            do
                echo "$line"
                cd "$line"
                cmd="./install.sh -p -i 1"
                echo $cmd
                $cmd
            done < "'$powerfly_refresh_list_file'"
        else
            echo "Image not downloaded."
        fi
    }
    pull_image
    '
    echo "$powerfly_refresh_file_content" > $powerfly_refresh_file
    chmod 777 $powerfly_refresh_file
    # Add powerfly_refresh_file for root user
    job="*/30 * * * * $powerfly_refresh_file 2>&1 | logger -t powerfly_refresh # check once, every 30 minutes"
    # Following line adds the $powerfly_refresh_file to crontab only if it is absent in (crontab -l).
    cat <(fgrep -i -v "$powerfly_refresh_file" <(crontab -l)) <(echo "$job") | crontab -
    Info "Cronjob installed [$powerfly_refresh_file]."
    echo "Cronjobs can be viewed with  [sudo crontab -l]."
}

### prints status of given service
do_status ()
{

    is_installed
    if [ $? != 0 ]; then
        docker image ls $url
        docker ps -a -f name=$service
    else
        Info "Service [$service] is not installed."
    fi
}

### Checks whether a service is installed
is_installed ()
{
    cmd="docker ps -q -a -f name=$service"
    list_of_containers=$($cmd)
    if [ -z "$list_of_containers" ]; then
        return 0
    fi
    return 1
}

### Installs a service
do_install ()
{
    docker_image=${url}${ver_str}
    if [ $local_docker == 0 ]
    then
        #Fetch image
        Info "Docker image    : $docker_image"
        if [ -f "$private_json" ]; then
            cmd="docker login -u _json_key --password-stdin https://us.gcr.io < $private_json"
            Info $cmd
            eval $cmd
        fi
        cmd="docker pull $docker_image "
        Info $cmd
        allowed_attempts=100
        for ((attempt=1;attempt<=allowed_attempts;attempt++)) ; do
            echo -n "Attempt [$attempt] "
            $cmd
            stat=$?
            if [ $stat == 0 ]; then
                break
            fi
        done
        cmd="docker logout https://us.gcr.io"
        Info $cmd
        $cmd
        if [ $stat != 0 ]; then
            Error "!!! Error Pulling [$docker_image]"
            do_exit 1
        fi
    else
        #Local docker image is to be used.
        if [ "$OSTYPE" == "linux-gnueabihf" ]
        then
            #This is for pi. So use arm7
            url=$url-arm7
            docker_image=${service_base}-arm7.docker
            Info "Fetching local image for $docker_image"
            cmd="docker load -i ${docker_image}"
            Info $cmd
            $cmd
            if [ $? != 0 ]; then
                Error "!!! Error Fetching [$docker_image]"
                do_exit 1
            fi
        else
            #This is not pi. So use amd4
            url=$url-amd64
        fi
    fi

    # do the installation
    Info "Installing service [$service] on [$device_id] from [$registry]"

    # if installed, and not interesetd to upgrade exit
    is_installed
    if [ $? != 0 ]; then
        read -p "Service [$service] exists, want to uninstall first? n/[Y]?" -r -n 1 SELECT
        echo ""
        if [[ $SELECT =~ ^[Nn]$ ]]
        then
            #Enable watchdog
            enable_watchdog_service

            Info "Not reinstalling service [$service]."
            do_exit 1
        fi

        #disable watchdog
        disable_watchdog_service

        # if interested uninstall first
        do_uninstall
    fi

    #disable watchdog
    disable_watchdog_service

    # everthing is fine good to start the container
    i=0
    for p in "${parameters[@]}"
    do

        if [ "$service_base" == "powerfly" ]
        then
            instance_suffix=""
        else
            instance_suffix="-${i}"
        fi
        cmd="docker run -it \
        --log-opt max-size=100m --log-opt max-file=1 \
        -d $p \
        --name ${service}${instance_suffix} \
        --restart unless-stopped \
        ${url}${ver_str} \
        ${binary_options} \
        "
        Info $cmd
        $cmd
        if [ $? != 0 ]; then
            Error "!!! Error installing the [$service] "
            do_exit 1
        fi
        i=$((i+1))
    done
    is_installed
    if [ $? == 1 ]; then
        Info "Service [$service] installed successfully "
        cmd="docker system prune --force"
        Info $cmd
        $cmd
        if [ "$service_base" == "powerfly" ] && [ "$environment" == "development" ]; then
            docker_refresh_image=$docker_image
            add_auto_upgrade_cronjob
        fi
        echo "5 second wait start"
        sleep 5
        echo "5 second wait complete"

        #Enable watchdog
        enable_watchdog_service

    else
        Error "!!! Error installing the [$service] "
    fi
    
}

### Uninstalls a service
do_uninstall ()
{
   # if not installed just return
   is_installed
   if [ $? == 0 ]; then
       Info " Service [$service] not installed"
       do_exit 1
   fi

   Info "Stopping service [$service]"

   # stop the container if running
   cmd="docker ps -q -f name=$service"
   Info $cmd
   list_of_containers=$($cmd)
   for c in $list_of_containers
   do
       Info "Stopping container [$c]"
       docker stop $c
       if [ $? != 0 ]; then
           Error "!!! ERROR Not able to stop the service [$c]"
           do_exit 1
       fi
   done

   # remove all containers
   cmd="docker ps -a -q -f name=$service"
   Info $cmd
   list_of_containers=$($cmd)
   for c in $list_of_containers
   do
       Info "Deleting container [$c]"
       docker container rm -f $c
       if [ $? != 0 ]; then
           Error "!!! ERROR Not able to delete the container [$c]"
           do_exit 1
       fi
   done

   # cross check
   is_installed
   if [ $? == 1 ]; then
       Error "Uninstalled failed"
       do_exit
   else
       Info "Uninstalled successfully"
   fi

   return 1

}

### Sets enviroment variables based on a service
set_env ()
{
    if [ $1 == $modbus_service_name ]; then
        binary_options="--device ${device_type} ${interval}"
        for ((i=0; i<$instances; i++))
        do
            map_port=$((from_port+i))
            parameters+=("--publish ${map_port}:1500 --privileged")
        done
    else
        # For now set the timezone as california
        timezone="America/Tijuana"
        c_timezone=`date +"%Z"`
        if [ "$c_timezone" == "IST" ]; then
          timezone="Asia/Kolkata"
        fi


        # add HW devices if it is PI
        devices=
        if [ "$OSTYPE" == "linux-gnueabihf" ]; then
#            devices="--device /dev/gpiomem --device /dev/ttyS0"
#            devices="-v /dev:/dev"
            devices=$devices" --device /dev/gpiomem "
            devices=$devices" --device /dev/ttyS0 "
            devices=$devices" --device /dev/ttyUSB0 "
            devices=$devices" --device /dev/ttyUSB1 "
            devices=$devices" --device /dev/ttyUSB2 "
        fi

        for ((i=0; i<$instances; i++))
        do
            parameters+=(" -e TZ=$timezone --privileged $devices -v `pwd`:/config -w /config")
        done
    fi

    service_file="$1".service
    service_path=$service_dir/$service_file
    url=$registry$service_base
}

### Update dhcpcd conf
update_dhcpcd_conf

### Main ###

# parse parameters
install=1
service=
status=
instances=1
version=
ver_str=
interval=

if [[ "$project" == *"development"* ]]; then
    version=develop
    ver_str=":$version"
    environment="development"
elif [[ "$project" == *"production"* ]]; then
    environment="production"
else
    environment="unknown"
fi

[ "$#" -lt 1 ] && usage

while [ "$1" != "" ]; do
    case $1 in
        -f | --file )           shift
                                filename=$1
                                ;;
        -i | --install )        [ -n "$uninstall" ] && usage || install=1
                                shift
                                instances=$(($1))
                                ;;
        -v | --version )        shift
                                version=$1
                                ver_str=":$version"
                                ;;
        -t | --port )           shift
                                from_port=$(($1))
                                ;;
        -e | --interval )       shift
                                interval="--interval $1"
                                ;;
        -u | --uninstall )      [ -n "$install" ] && usage || install=0
                                ;;
        -m | --modbus )         [ -n "$service" ] && usage || service=$modbus_service_name
                                shift
                                device_type=$1
                                service_base=$service
                                ;;
        -p | --powerfly )       [ -n "$service" ] && usage || service=$powerfly_service_name
                                service_base=$service
                                ;;
        -l | --local )          local_docker=1;
                                ver_str=":local"
                                ;;
        -s | --status )         status=1
                                ;;
        -h | --help )           usage
                                do_exit
                                ;;
        * )                     usage
                                do_exit 1
    esac
    shift
done

if [ "$service_base" == "powerfly" ]
then
    #only one instance for powerfly
    instances=1
fi

### Validate options
[ -n "$status" ]  && [ -z "$service" ] && usage
[ -n "$install" ] && [ -z "$service" ] && usage
[ $local_docker == 1 ] && [ -z "$service" ] && echo "provide service -p or -m " && usage
[ $instances == 0 ] && echo "Instances should greater than 0" && usage


### Set enviroment acc to service
set_env "$service"

### add device type to service
if [ -n "$device_type" ]; then
  if [ "$device_type" != "inverter" ] \
  && [ "$device_type" != "carboncap" ] \
  && [ "$device_type" != "pb_carboncap" ] \
  && [ "$device_type" != "meter" ] \
  && [ "$device_type" != "solectria" ] \
  && [ "$device_type" != "hawk-1000" ] \
  && [ "$device_type" != "delta-M80" ] \
  && [ "$device_type" != "delta_PCS125" ] \
  && [ "$device_type" != "delta_PCSBMS125" ] \
  && [ "$device_type" != "delta-PCS125kW" ] \
  && [ "$device_type" != "BACNetServerSim" ] \
  && [ "$device_type" != "hiq-solar" ] \
  && [ "$device_type" != "l-acuvim" ] \
  && [ "$device_type" != "c2_acuvim" ] \
  && [ "$device_type" != "conext_gw_502" ] \
  && [ "$device_type" != "conext_xw_502" ] \
  && [ "$device_type" != "conext_gw_503" ] \
  && [ "$device_type" != "conext_xw_503" ] \
  && [ "$device_type" != "delta_essbd" ] \
  && [ "$device_type" != "sebms2" ] \
  && [ "$device_type" != "acurev_2100" ] \
  && [ "$device_type" != "acuvim" ]; then
    Error "Unsupported device [$device_type]" && usage
  fi
  service="$service-$device_type"
else
  # form service name for powerfly 
  service="$service-$device_id"
fi

### Call status if asked
if [ -n "$status" ]; then
    do_status
    do_exit
fi

### Install or Uninstal
if [ -n "$install" ]; then
    if [ $install == 1 ]; then
        do_install
    else
        do_uninstall
    fi
fi

do_exit 0

