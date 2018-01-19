#!/bin/bash

cd `dirname  $0`
echo "now :$(date)"
if [ `ls |grep "nginx_[a-z]*.conf"|wc -l` -ne 1 ];then echo "Please config nginx conf";exit 0;fi
dbhost=`cat nginx_*.conf |grep -v dist|grep db_string|cut -d ';' -f 1|cut -d '"' -f 2`
dbport=`cat nginx_*.conf |grep -v dist|grep db_string|cut -d ';' -f 2`
dbuser=`cat nginx_*.conf |grep -v dist|grep db_string|cut -d ';' -f 3`
dbpwd=`cat nginx_*.conf |grep -v dist|grep db_string|cut -d ';' -f 4`
mycmd="mongo $dbhost:$dbport/admin -u $dbuser -p $dbpwd --eval  \"load('createIndex.js')\""
echo $mycmd >>/var/log/timer.log
eval $mycmd

