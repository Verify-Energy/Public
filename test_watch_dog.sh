#!/bin/bash

# grep "dtparam=watchdog=on" /boot/config.txt
# 
# grep dtparam=watchdog=on /boot/config.txt -c
# 
# cmd="grep dtparam=watchdog=on /boot/config.txt -c"
# watchdog_enabled=$($cmd)
# 
# 
# FILE=/dev/watchdog
# if test -f "$FILE"; then
#     echo "$FILE exists."
# else 
#     echo "$FILE does not exist."
# fi

#powerfly_log=$('pwd')/logging.txt
#
#echo '#Watchdog Config for PowerFly' >> pop.txt
#echo 'watchdog-device = /dev/watchdog' >> pop.txt
#echo 'watchdog-timeout = 60' >> pop.txt
#echo 'max-load-1 = 24' >> pop.txt
#echo ' file = 'sample_file  >> pop.txt
#echo '#file = 'sample_file  >> pop.txt
#echo ' file = 'sample_file  >> pop.txt
#echo ' file = 'sample_file  >> pop.txt
#echo 'change = 60'  >> pop.txt
#
#sed -i 's@ file = [a-zA-Z0-9_-]*@ file = '$powerfly_log'@g' pop.txt
#
#exit 0

is_watchdog_in_boot_config ()
{
    cmd="grep dtparam=watchdog=on /boot/config.txt -c"
    watchdog_enabled=$($cmd)
    if [ $watchdog_enabled == 0 ]; then
        #echo is_watchdog_in_boot_config ret 0
        return 0
    fi
    #echo is_watchdog_in_boot_config ret 1
    return 1  
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
    sed -i 's@file = [a-zA-Z0-9_-]*@file = '$powerfly_log'@g' /etc/watchdog.conf
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

enable_watchdog_service()
{
    systemctl enable watchdog
    systemctl start watchdog
    systemctl status watchdog
}

is_watchdog_service_enabled()
{
    cmd='systemctl is-active watchdog'
    service_state=$($cmd)
    if [ $service_state == "active" ]; then
        return 1 ;
    fi
    return 0
}

watchdog_init ()
{
    is_watchdog_dev_present
    watchdog_dev_presence=$?
    if [ $watchdog_dev_presence == 1 ]; then
        is_watchdog_installed
        installed_status=$?
        if [ $installed_status == 1 ]; then
            echo "Watchdog installed and ready"
            is_watchdog_configured
            config_status=$?
            if [ $config_status == 0 ]; then
                echo "Watchdog config being added"
                add_watchdog_config
                is_watchdog_configured
                config_status=$?
                if [ $config_status == 1 ]; then
                    echo "Watchdog Config success"
                else
                    echo "Error: Watchdog Config Add Failed"
                fi           
            else
                echo "Watchdog config being updated"
                update_watchdog_config
            fi

        else
            echo "Install watchdog"
            install_watchdog
            is_watchdog_installed
            installed_status=$?
            if [ $installed_status == 1 ]; then
                echo "Watchdog installed and ready"
                is_watchdog_configured
                config_status=$?
                if [ $config_status == 0 ]; then
                    echo "Watchdog config being added"
                    add_watchdog_config
                    is_watchdog_configured
                    config_status=$?
                    if [ $config_status == 1 ]; then
                        echo "Watchdog Config success"
                    else
                        echo "Error: Watchdog Config Add Failed"
                    fi              
                else
                    echo "Watchdog config being updated"
                    update_watchdog_config
                fi
            else
                echo "Error: Watchdog installation failed."
            fi

        fi
    else
        check_kernel_watchdog
        kernel_watchdog_presence=$?
        echo kernel_watchdog_presence is $kernel_watchdog_presence
        if [ $kernel_watchdog_presence == 0 ]; then
            enable_kernel_watchdog
            check_kernel_watchdog
            kernel_watchdog_presence=$?
            if [ $kernel_watchdog_presence == 1 ]; then
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
    is_watchdog_service_enabled
    watchdog_service_state=$?
    if [ $watchdog_service_state == "0" ]; then
        enable_watchdog_service
    fi
    is_watchdog_service_enabled
    watchdog_service_state=$?
    if [ $watchdog_service_state == "0" ]; then
            echo "Error: Unable to start service"
    fi

}

watchdog_init
