#!/bin/bash

step=10

while(true) do       
    #充值10s一跳
    echo `date +%F_%T` "recharge update"        
    curl --connect-timeout 10 -m 20 "http://127.0.0.1:30080/gm_intf/update_gm_recharge" > /dev/null    
    
    sleep $step
done