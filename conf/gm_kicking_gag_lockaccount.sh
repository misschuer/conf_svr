#!/bin/bash

step=20

while(true) do
    #20s一跳
    echo `date +%F_%T` "kicking update"
    curl --connect-timeout 10 -m 60 "http://127.0.0.1:30080/gm_intf/update_gm_kicking" > /dev/null
    echo `date +%F_%T` "gag update"
    curl --connect-timeout 10 -m 60 "http://127.0.0.1:30080/gm_intf/update_gm_gag" > /dev/null
    echo `date +%F_%T` "lock_account update"
    curl --connect-timeout 10 -m 60 "http://127.0.0.1:30080/gm_intf/update_gm_lock_account" > /dev/null
    sleep $step
done
