#!/bin/bash

step=30

while(true) do
    echo `date +%F_%T` "gift update"
    curl --connect-timeout 10 -m 60 "http://127.0.0.1:30080/gm_intf/update_gm_gift_packs" > /dev/null
    echo `date +%F_%T` "notice update"
    curl --connect-timeout 10 -m 60 "http://127.0.0.1:30080/gm_intf/update_gm_notice" > /dev/null    
    sleep $step
done
