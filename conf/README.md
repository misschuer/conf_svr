conf_svr

# git 地址
* 国服 ssh://gitdown@tssj_git.game2.com.cn:6688/~/conf_svr.git
* 腾讯 ssh://gitdown@61.160.241.147:6688/~/conf_svr.git
* 韩国 ssh://gitdown@114.108.172.140:59878/~/conf_svr.git
* 台湾 ssh://gitdown@203.75.237.148:59878/~/conf_svr.git


# 共享缓存配置(必须)
    
* lua_shared_dict mem_locks 10m;
* lua_shared_dict dogs 200m;
* lua_shared_dict app_addr 100m;	
* lua_shared_dict gmIntf_lockaccount_cache 200m;
* lua_shared_dict gmIntf_notice_cache 200m;	
* lua_shared_dict gmIntf_qqinfo_cache 200m;	


##目前用到的配置项只有腾讯版
db.server_config.save({pid:360,key:"tencent_web_intf",value:"http://192.168.30.11:10080/"})

充值修改：
循环遍历load到的所有充值订单，每100条推送一次，其中如果一个玩家有一个订单没有处理成功，那么这个玩家的后续订单就不在处理，等下次心跳进来在处理


