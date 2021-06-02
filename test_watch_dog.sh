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


check_kernel_watchdog ()
{
    cmd="grep dtparam=watchdog=on /boot/config.txt -c"
    watchdog_enabled=$($cmd)
    if [ $watchdog_enabled == 0 ]; then
        echo check_kernel_watchdog ret 0
        return 0
    fi
    echo check_kernel_watchdog ret 1
    return 1  
}

enable_kernel_watchdog ()
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
    echo 'watchdog-device = /dev/watchdog' >> /etc/watchdog.conf
    echo 'watchdog-timeout = 15' >> /etc/watchdog.conf
    echo 'max-load-1 = 24' >> /etc/watchdog.conf    
}

configure_watchdog ()
{
    echo 'watchdog-device = /dev/watchdog' >> /etc/watchdog.conf
    echo 'watchdog-timeout = 15' >> /etc/watchdog.conf
    echo 'max-load-1 = 24' >> /etc/watchdog.conf    
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
    #check_kernel_watchdog
    #kernel_watchdog_presence=$?
    #echo kernel_watchdog_presence is $kernel_watchdog_presence
    #if [ $kernel_watchdog_presence == 0 ]; then
    #    enable_kernel_watchdog
    #    check_kernel_watchdog
    #    kernel_watchdog_presence=$?
    #    if [ $kernel_watchdog_presence == 1 ]; then
    #        echo ready to reboot
    #    else
    #        echo unable to write to boot config
    #    fi
    #else
        is_watchdog_dev_present
        watchdog_dev_presence=$?
        if [ $watchdog_dev_presence == 1 ]; then
            is_watchdog_installed
            installed_status=$?
            if [ $installed_status == 1 ]; then
                echo "Watchdog installed and ready"
            else
                echo "Install watchdog"
                install_watchdog
                configure_watchdog
                is_watchdog_installed
                installed_status=$?
                if [ $installed_status == 1 ]; then
                    echo "Watchdog installed and ready"
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
                    echo "Ready to reboot"
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
    #fi
}

watchdog_init
