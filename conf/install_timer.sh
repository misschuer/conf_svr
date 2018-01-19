#!/bin/bash
cd `dirname $0`
path=`pwd`
name=`echo $path |awk -F '/' '{print $3}'`
if [ $name == "conf_svr" ]
then 
    (crontab -l|grep -v ${path};echo "4 * * * * ${path}/create_index_timer.sh >> /var/log/${name}_timer.log")|crontab
elif [ $name == "ext_web" ]
then
    (crontab -l|grep -v ${path};echo "14 * * * * ${path}/create_index_timer.sh >> /var/log/${name}_timer.log")|crontab
else
    (crontab -l|grep -v ${path};echo "24 * * * * ${path}/create_index_timer.sh >> /var/log/${name}_timer.log")|crontab
fi
    
#执行中间件心跳定时器
if [ `ls |grep gm_recharge.sh|wc -l` -eq 1 ]
then 
    kill `ps aux | grep gm_recharge.sh | grep -v grep | awk '{print $2}'`
    echo "start gm_recharge.sh"
	nohup ${path}/gm_recharge.sh >> /var/log/gm_recharge.log 2>&1 &
fi
sleep 1
if [ `ls |grep gm_gift_notice.sh|wc -l` -eq 1 ]
then 
    kill `ps aux | grep gm_gift_notice.sh | grep -v grep | awk '{print $2}'`
    echo "start gm_gift_notice.sh"
	nohup ${path}/gm_gift_notice.sh >> /var/log/gm_gift_notice.log 2>&1 &
fi
sleep 1
if [ `ls |grep gm_kicking_gag_lockaccount.sh|wc -l` -eq 1 ]
then 
    kill `ps aux | grep gm_kicking_gag_lockaccount.sh | grep -v grep | awk '{print $2}'`
    echo "start gm_kicking_gag_lockaccount.sh"
	nohup ${path}/gm_kicking_gag_lockaccount.sh >> /var/log/gm_kicking_gag_lockaccount.log 2>&1 &
fi
sleep 1
if [ `ls |grep gm_qq_level_inaccount.sh|wc -l` -eq 1 ]
then 
	echo "start gm_qq_level_inaccount.sh"
    kill `ps aux | grep gm_qq_level_inaccount.sh | grep -v grep | awk '{print $2}'`
	nohup ${path}/gm_qq_level_inaccount.sh >> /var/log/gm_qq_level_inaccount.log 2>&1 &
fi
