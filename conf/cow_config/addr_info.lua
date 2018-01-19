local cjson = require 'cjson'
local dbMgr = require 'util.db_access'
local router_cls = require 'util.router_map'
local vaildArgs = router_cls.vaildArgs

local _M = {
	refresh_internal = 60,	--刷新缓存间隔（1分钟）
	cache = {
		recacheTime = -1,		--上一次的刷新时间戳
		updateTime = -1,		--刷新时间，跟cow_config.addr_update_sign表里的u_update_time对比
		data = {},				--缓存地址信息
	},
}

--获取数据库表对象
function _M.get_tbl( dbname )
	local db = dbMgr.getDBObj('cow_config')		
	if not db then
		return nil
	end
	local dbname = dbname or "addr_info"
    return db[dbname]
end

--获得cow_config.addr_update_sign里的update_time
function _M.getUpdateTime(  )	
	local tbl = _M.get_tbl("addr_update_sign")
	if not tbl then return end
	local r = tbl:findOne()
	if r and r.u_update_time then
		return r.u_update_time
	end
end

--加载地址信息
function _M.loadAddrInfo(  )
	local rows = {}
	
	local tbl = _M.get_tbl()
	if not tbl then
		return rows
	end
	
	local where ={ } 
	local c = tbl:find( where)
	while c:hasNext() do
		local r = c:next()
		if r and table.nums(r) > 0 then
			table.insert(rows, r)
		end
    end
	
	return rows	
end


--刷新缓存
function _M.refreshCache( force )
	local need_refresh = force or false

	local timenow = os.time()
	local updateTime = _M.getUpdateTime() 
	--不是强制刷新的话，看下上一层刷新是否已经过了1分钟
	if not need_refresh and (_M.cache.recacheTime == -1 or timenow - _M.cache.recacheTime > _M.refresh_internal ) then
		--其实可以合并成一个判断，不过这样可读性太差了点
		if not updateTime or ( updateTime and (_M.cache.updateTime == -1 or _M.cache.updateTime ~= updateTime) ) then
			need_refresh = true
		end		
	end

	if not need_refresh then
		return 	--还不需要刷新缓存
	end

	local results = _M.loadAddrInfo()
	for _, info in ipairs(results) do
		local server_names = string.split(info.server_name_list, ";")
		for _,server_name in ipairs(server_names) do
			_M.cache.data[server_name] = info.host_port
		end
	end

	--更新刷新时间
	_M.cache.recacheTime = timenow
	_M.cache.updateTime = updateTime
end


--获取列表
function _M.list()
	_M.refreshCache()			--不管怎样刷新下缓存
	local data = _M.cache.data

	local params = cjson.encode(data) or ""
	ngx.print(params)
end

-- 获取指定的server_name的地址信息 客户端用
function _M.info( )
	_M.refreshCache()			--不管怎样刷新下缓存
	local args = vaildArgs( {"pid", "sid"})
	if not args then return end
	
	local ip, port
	local data = _M.cache.data
	local host_port = data[args["pid"].."_"..args["sid"]]
	if host_port then
		local token = string.split(host_port, ":")
		if #token == 2 then
			ip = token[1]
			port = token[2]
		end
	end

	if ip and port then
		ngx.print(string.format("var config = {loginip:'%s',loginport:%s}",ip,port))
	end
end

-- 获取指定的server_name的地址信息 服务端用
function _M.get( )
	_M.refreshCache()
	local args = vaildArgs( {"server_name"})
	if not args then return end

	local ip, port
	local data = _M.cache.data
	local host_port = data[args["server_name"]] or ""
	ngx.print("ipport="..host_port)
end


--更新信息
function _M.put( )
	_M.refreshCache()			--不管怎样刷新下缓存
	local args = router_cls.getArgs()
	local server_names = ""
	local host_port = ""
	for k,v in pairs(args) do
		server_names = k
		host_port = v
		break
	end
	if server_names =="" or host_port=="" then
		return
	end
	
	local server_names = string.split(server_names,";")
	local data = _M.cache.data
	for _,server_name in ipairs(server_names) do
		data[server_name] = host_port
	end

	ngx.print("ok")
end


function _M:extend(hanlder)
	hanlder['/cow_config/addr_info/list'] = self.list
	hanlder['/info'] = self.info 					--暴露给客户端用的
	hanlder['/cow_config/addr_info/put'] = self.put
	hanlder['/cow_config/addr_info/get'] = self.get
end

return _M