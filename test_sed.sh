#!/bin/bash

#WATCHDOG_CONF_FILE="/etc/watchdog.conf"
WATCHDOG_CONF_FILE="watchdog.conf"
PF_LOG_NAME="/logging.txt"
DER_LOG_NAME="/DERCtrl_logging.txt"
powerfly_log=$('pwd')$PF_LOG_NAME
DERCtrl_log=$('pwd')$DER_LOG_NAME
delete_line='DELETE LINE'

replace_watchdog_config_powerfly ()
{
    #replace existing powerfly log file path with this new one.
    cmd="sed 's@file = [a-zA-Z0-9_./-]*$PF_LOG_NAME@file = $powerfly_log@' $WATCHDOG_CONF_FILE | tee $WATCHDOG_CONF_FILE "
    echo $cmd
    eval temp=\`${cmd}\`
}

add_watchdog_config_DERCtrl ()
{
    #Add DERCtrl log file .
    echo 'file = '$DERCtrl_log  >> $WATCHDOG_CONF_FILE
    echo 'change = 60'  >> $WATCHDOG_CONF_FILE
}

remove_watchdog_config_DERCtrl ()
{
    #remove existing DERCtrl log file path.

    #sed '/{START-TAG/{:1;/END-TAG}/!{N;b1};/ID: *222/d}'
    #cmd="sed -i '' '/file = *$DER_LOG_NAME/{:1;/change = 60/d}' $WATCHDOG_CONF_FILE"
    #sed '/^tomcat\.util.*$/,/^.*[^\]$/d' /tmp/foobar.txt
    # sed  '/file = [a-zA-Z0-9_./-]*DERCtrl_logging.txt/,/change = 60/d' watchdog.conf
    #sed  '/file = [a-zA-Z0-9_/-]*\/DERCtrl_logging.txt/,/change = 60/d' watchdog.conf
    cmd="sed -i '' '/file = [a-zA-Z0-9_./-]*\\$DER_LOG_NAME/,/change = 60/d' $WATCHDOG_CONF_FILE"
    echo $cmd
    eval temp=\`${cmd}\`

    #cmd="sed -i '' 's@file = [a-zA-Z0-9_./-]*$DER_LOG_NAME@$delete_line@' $WATCHDOG_CONF_FILE "
    #echo $cmd
    #eval temp=\`${cmd}\`
    #cmd="sed -i '' '/$delete_line/d' $WATCHDOG_CONF_FILE"
    #echo $cmd
    #eval temp=\`${cmd}\`
}

watchdog_marker="#Watchdog Config for PowerFly"

add_watchdog_config ()
{
    echo $watchdog_marker >> $WATCHDOG_CONF_FILE
    echo 'watchdog-timeout = 60' >> $WATCHDOG_CONF_FILE
    echo 'max-load-1 = 24' >> $WATCHDOG_CONF_FILE
    echo 'file = '$powerfly_log  >> $WATCHDOG_CONF_FILE
    echo 'change = 60'  >> $WATCHDOG_CONF_FILE
}

is_watchdog_configured ()
{
#    cmd="grep '"$watchdog_marker"' "$WATCHDOG_CONF_FILE" -c"
    cmd="grep '$watchdog_marker' $WATCHDOG_CONF_FILE -c"
    #echo $cmd
    eval watchdog_configured=\`${cmd}\`
    #echo watchdog_configured $watchdog_configured
    if [ $watchdog_configured == 0 ]; then
        echo is_watchdog_configured 0
        return 0
    fi
        echo is_watchdog_configured 1
    return 1  
}

watchdog_init ()
{
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
        #replace_watchdog_config_powerfly
        remove_watchdog_config_DERCtrl
        #add_watchdog_config_DERCtrl
    fi

}

watchdog_init