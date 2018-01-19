
mid=`ps -ef|grep nginx_conf_svr.conf|grep -v grep|awk {'print $2'}`
if !([ -z "$mid" ];) then
    echo "killed nginx_conf_svr.conf", $mid
    kill $mid 
fi
