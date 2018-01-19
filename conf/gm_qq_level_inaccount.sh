#!/bin/bash

step=60
while(true) do
    #10min一跳 
    echo `date +%F_%T` "gm_level update"
    curl --connect-timeout 10 -m 60 "http://127.0.0.1:30080/gm_intf/update_gm_level" > /dev/null
    echo `date +%F_%T` "qq_info update"
    curl --connect-timeout 10 -m 60 "http://127.0.0.1:30080/gm_intf/update_gm_qq_config" > /dev/null
    echo `date +%F_%T` "inaccount update"
    curl --connect-timeout 10 -m 60 "http://127.0.0.1:30080/gm_intf/update_gm_inaccount_list" > /dev/null     
    sleep $step
done