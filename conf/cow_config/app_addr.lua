--------------------
-- 应用地址注册表
--------------------

local dbMgr = require 'util.db_access'
local cjson = require 'cjson'
local http = require "resty.http"

local router_cls = require 'util.router_map'
local vaildArgs = router_cls.vaildArgs
local cache  = ngx.shared.app_addr --共享缓存
local cache_timeout = 60

local _M = {}

--全量刷新缓存数据
function _M.loadCache()

	local toReload =  false
	local time = os.time()
	local update_time = cache:get("update_time") or 0
    cache:set("update_time", time)

	--判断缓存时间是否超时,超时的话，设置刷新状态为 true
	if update_time == 0 or update_time + cache_timeout >=  time then
		toReload =true
	end

	--未超时，则直接返回缓存
	if toReload == false  then return false end

	--库里面刷新缓存
	local db = dbMgr.getDBObj('cow_config')
	local tbl = db.app_addr

	local reader = tbl:find()
	while reader:hasNext() do

		local row = reader:next()
		if not row or not row.server_name then break end

		local server_name = row.server_name or ""
		local server_type = row.server_type or ""
		local host_port = row.host_port or ""

		_M.updateCache(server_name, server_type, host_port)
	end

	return true
end

--更新缓存某项数据
function _M.updateCache(server_name, server_type, host_port )
	local cacheKey = server_name.."_"..server_type
	local data =  {
			server_name =server_name,
			host_port = host_port,
			server_type	= server_type
		}

	cache:set(cacheKey, cjson.encode(data))
end

--获取缓存某项数据
function _M.getCache(server_name, server_type)
	local cacheKey = server_name.."_"..server_type
	local data = cache:get(cacheKey)

	return _M.tryDecode(data)
end

function _M.put()

	local args = vaildArgs( {"server_names","port","type"})
	if not args then return end

	local port = args["port"]  or  ""
	local host = args["host"] or ""
	local server_names = args["server_names"] or ""
	local server_type = args["type"] or ""

	--获取来访者ip
	if host =="" then
		host =ngx.var.remote_addr
	end
	local host_port = host..":"..port

	--更新数据库
	local db  = dbMgr.getDBObj('cow_config')
	local tbl = db.app_addr

	local serverTb = string.split(server_names,";")
	for i=1,#serverTb do
		tbl:update(
				{server_name = serverTb[i], server_type = server_type},
				{["$set"] = {host_port = host_port}},
				true,false
			)
	end

	--r = db:runCommand("getLastError",1,"w",1)
	--if r.ok~=1 then
	--	ngx.say(cjson.encode({ret=1,msg="no"}))
	--	return
	--end

	--如果没有从库里刷新缓存，那么就手动刷新一下
	--if not _M.loadCache() then
		for i=1,#serverTb do
			_M.updateCache(serverTb[i], server_type, host_port)
		end
	--end

	ngx.say(cjson.encode({ret=0,msg="ok"}))
end

function _M.get()

    local args = vaildArgs({"server_name","type"})
    if not args then return end

	local server_name = args["server_name"] or ""
	local server_type = args["type"] or ""

	--_M.loadCache() --刷新一下缓存 
	
	local data = _M.getCache(server_name, server_type)
	if not data then
		ngx.say(cjson.encode({ret = 1,msg = "data is nil"}))
		return
	end

	ngx.say(cjson.encode({ret = 0,msg = "",data = data.host_port }))
end

function _M.clear()
	--实际上只是把所有的项标注为过期，内存并未释放,这个是nginx的处理机制
	cache:flush_all()
	ngx.say(cjson.encode({ret = 0,msg = "ok"}))
end

function  _M.tryDecode(jsonStr)
	local o = nil
	local status, err = pcall(function (  )
		o = cjson.decode(jsonStr)
	end)
	if not status then
		return nil, err
	end
	return o
end

-- 收到平台来的充值消息
function _M.payed()
	local args = vaildArgs({"payid", "orderid", "ext", "paytime", "goodsname", "money", "goodsnum", "sign"})
	if not args then return end
	
	local payid 		= args["payid"] or ""
	local orderid 		= args["orderid"] or ""
	local ext 			= args["ext"] or ""
	local paytime 		= args["paytime"] or ""
	local goodsname 	= args["goodsname"] or ""
	local money 		= args["money"] or ""
	local goodsnum 		= args["goodsnum"] or ""
	local sign 			= args["sign"] or ""
	
	local data = _M.getCache(ext, 'appd')
	if not data then
		ngx.say(cjson.encode({ret = false, ext = ext}))
		return
	end
	
	local host_port = data.host_port
	
	_M.resend(host_port, payid, orderid, ext, paytime, goodsname, money, goodsnum, sign)
end


function _M.resend(host_port, payid, orderid, ext, paytime, goodsname, money, goodsnum, sign)
	local data = cjson.encode({payid = payid, orderid = orderid, ext = ext, paytime = paytime, goodsname = goodsname, money = money, goodsnum = goodsnum, sign = sign})
	-- 正常请求
	local httpc = http.new();
	httpc.timeout = 2000;
	local res, err = httpc:request_uri("http://"..host_port.."/external/recharge", {
		method = "POST",
		body = data
	})
	
	if res then
		if 200 ~= res.status then
			ngx.log(ngx.ERR, "/gm_intf/gm_recharge -error:", res.status, "  data:", data)
		else
			ngx.say("success")
		end
	else
		ngx.log(ngx.ERR, "post data to /gm_intf/gm_recharge -error:", err)
	end
end


function _M:extend(hanlder)
    hanlder['/cow_config/app_addr/reg'] = self.put		--更新或新增一条数据
	hanlder['/cow_config/app_addr/query'] = self.get		--查看指定server_name,type 的 host_port
	hanlder['/cow_config/app_addr/clear'] = self.clear		--清理缓存
	hanlder['/cow_config/app_addr/payed'] = self.payed		--得到充值成功信息 分发给重置服务器
end

return _M

