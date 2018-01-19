#!/bin/bash

step=10
count=0
count_20s=0
count_1min=0
count_10min=0

while(true) do
    let count=${count}+1
    let count_20s=${count}%2
    let count_1min=${count}%6
    let count_10min=${count}%60
    echo $count $count_20s $count_1min $count_10min
    if [ ${count_20s} -eq 0 ]
    then
        #20s一跳
        echo `date +%F_%T` "20s update"        
        curl "http://127.0.0.1:30080/gm_intf/update_gm_kicking" > /dev/null
        curl "http://127.0.0.1:30080/gm_intf/update_gm_gag" > /dev/null
        curl "http://127.0.0.1:30080/gm_intf/update_gm_lock_account" > /dev/null
        curl "http://127.0.0.1:30080/gm_intf/update_gm_recharge" > /dev/null
    fi

    if [ ${count_1min} -eq 0 ]
    then
        #1min一跳
        echo `date +%F_%T` "1min update"
        curl "http://127.0.0.1:30080/gm_intf/update_gm_gift_packs" > /dev/null
        curl "http://127.0.0.1:30080/gm_intf/update_gm_notice" > /dev/null
        curl "http://127.0.0.1:30080/gm_intf/update_gm_inaccount_list" > /dev/null
    fi

    if [ ${count_10min} -eq 0 ]
    then
        #10min一跳 
        echo `date +%F_%T` "10min update"
        curl "http://127.0.0.1:30080/gm_intf/update_gm_level" > /dev/null
        curl "http://127.0.0.1:30080/gm_intf/update_gm_qq_config" > /dev/null        
    fi
    
    sleep $step
done
