--------------------
--server_info 应用地址注册表
--------------------

local dbMgr = require 'util.db_access'
local cjson = require 'cjson'

local router_cls = require 'util.router_map'
local vaildArgs = router_cls.vaildArgs


local _M = {
    cache = {},
	cache_timeout = 60,
    update_time = 0
}

function _M.loadCache()

	local toReload =  false
	local time =os.time()

	--判断缓存时间是否超时,超时的话，设置刷新状态为 true
	if _M.update_time == 0 or _M.update_time + _M.cache_timeout >=  time then
		toReload =true
	end

	--未超时，则直接返回缓存
	if toReload == false  then return _M.cache end

	--库里面刷新缓存
	local db = dbMgr.getDBObj('cow_config')
	local tbl = db.app_addr

	local reader = tbl:find()
	while reader:hasNext() do

		local row = reader:next()
		if not row or not row.server_name then break end

		local server_name =row.server_name or ""

		_M.cache[server_name]={
				server_name 	 = server_name,
				u_open_time  	 = row.u_open_time or 0,
				i_merge_status 	 = row.i_merge_status  or 0,
				host 			 = row.host or "",
				i_port			 = row.i_port or  0,
				i_server_type	 = row.i_server_type or 0
		}
	end

	_M.update_time = time
	return _M.cache
end

function _M.__getInfo( ... )
	
end

function _M.put()

	local args = vaildArgs( {"server_name"})
	if not args then return end

	local server_name = args["server_name"]
	local i_merge_status = tonumber(args["i_merge_status"]) or -1
	local u_open_time = tonumber(args["u_open_time"]) or -1

	local where = {server_name = server_name}
	local values 
	if i_merge_status ~= -1 then
		values = values or {}
		values.i_merge_status = i_merge_status
	end
	if u_open_time ~= -1 then
		values = values or {}
		values.u_open_time = u_open_time
	end

	if not values then
		ngx.say(cjson.encode({ret=1,msg="参数无效"}))
		return
	end

	--更新数据库
	local db  = dbMgr.getDBObj('cow_config')
	local tbl = db.server_info

	tbl:update(where ,{["$set"] = values} ,true ,false )

	r = db:runCommand("getLastError",1,"w",1)
	if r.ok~=1 then
		ngx.say(cjson.encode({ret=1,msg="no"}))
		return
	end

	--更新缓存
	local row_cache =_M.loadCache()[server_name]
	if row_cache then
		for k,v in pairs(values) do
			row_cache[k] = v
		end
	end


	ngx.say(cjson.encode({ret=0,msg="ok"}))
end

function _M.get()

    local args = vaildArgs({"server_name"})
    if not args then return end

	local server_name = args["server_name"] or ""

	local data = _M.loadCache()[server_name]
	if not data then
		ngx.say(cjson.encode({ret = 1 ,msg = "data is nil"}))
		return
	end

	ngx.say(cjson.encode({ret = 0 ,msg = "" ,data = data }))

end


function _M.clear()
    _M.cache = {}
	_M.update_time = 0
	ngx.say(cjson.encode({ret = 0,msg = "ok"}))
end

function _M:extend(hanlder)
    hanlder['/cow_config/server_info/put'] = self.put		--更新或新增一条数据
	hanlder['/cow_config/server_info/query'] = self.get		--查看
    hanlder['/cow_config/server_info/clear'] = self.clear	--移除缓存
end

return _M

