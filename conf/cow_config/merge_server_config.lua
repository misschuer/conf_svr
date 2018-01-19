
--------------------
-- 合服配置表， 这边缓存策略依赖 更新时间 ，ngx.shared.dogs:set("merge_server_config_cache_update_time")
--------------------

assert(ngx.shared.dogs, "nginx conf 未配置共享缓存对象 ngx.shared.dogs")

local dbMgr = require 'util.db_access'
local cjson = require 'cjson'
local router_cls = require 'util.router_map'
local vaildArgs = router_cls.vaildArgs


local ngx_cache = ngx.shared.dogs			--缓存
local map_server_type = {
			MERGE_SERVER_TYPE_ORIGINAL = 1 , --原始服务器
			MERGE_SERVER_TYPE_TARGAT   = 2	 --目标服务器
		}
--------------------------------------------------------------------

local _M = {
    cache = {},
    update_time = 0
}

--更新缓存过期时间
function _M.update_ngx_cache_time()
	ngx_cache:set("merge_server_config_cache_update_time",os.time())
end

--获取缓存过期时间
function _M.get_ngx_cahce_time()
	return ngx_cache:get("merge_server_config_cache_update_time") or 0
end

--加载缓存数据
function _M.loadCache()

	local time = os.time()
	local ngx_cache_time =  _M.get_ngx_cahce_time()

	local toReload =  false

	--判断缓存时间是否超时,超时的话，设置刷新状态为 true
	if _M.update_time == 0 or _M.update_time < ngx_cache_time then
		toReload =true
	end

	--未超时，则直接返回缓存
	if toReload == false  then return _M.cache end

	--库里面刷新缓存
	local db = dbMgr.getDBObj('cow_config')
	local tbl = db.merge_server_config

	local reader = tbl:find()
	while reader:hasNext() do

		local row = reader:next()
		if not row  then break end

		local merge_server_name = row.merge_server_name or ""
		local server_name = row.server_name  or ""
		local i_opt_status = tonumber(row.i_opt_status) or -1

		_M.cache[merge_server_name.."_"..server_name]={
				merge_server_name = merge_server_name,
				server_name	 	  = server_name,
				i_opt_status	  = i_opt_status
			}
	end

	_M.update_time = time
	return _M.cache
end


function _M.put()

	local args = vaildArgs( {"merge_server_name","server_name","status"} )
	if not args then return end

	local merge_server_name = args["merge_server_name"]  or  ""
	local server_name = args["server_name"] or ""
	local status = tonumber(args["status"]) or 0

	--更新数据库
	local db  = dbMgr.getDBObj('cow_config')
	local tbl = db.merge_server_config

	local where  = { merge_server_name =  merge_server_name, server_name = server_name }
	local values = { ["$set"] = { i_opt_status = status } }
	tbl:update(where, values, true, false)

	r = db:runCommand("getLastError",1,"w",1)
	if r.ok~=1 then
		ngx.say(cjson.encode({ret=1,msg="db CURE error"}))
		return
	end

	--更新缓存过期时间
	_M.update_ngx_cache_time()

	ngx.say(cjson.encode({ret=0,msg="ok"}))
end

function _M.get()

	local args = vaildArgs( {"server_name","server_type","status"} )
	if not args then return end

	local status = tonumber(args["status"]) or -1
	local server_name = args["server_name"] or ""
	local server_type = args["server_type"] or -1

	local cache = _M.loadCache() -- 刷新缓存

	local where_svr = "server_name"
	if server_type == map_server_type.MERGE_SERVER_TYPE_TARGAT then	--目标服务器
		where_svr = "merge_server_name"
	end

	local data = {}
	for k,row in pairs(cache) do
		if row[where_svr] == server_name and row.i_opt_status == status then
			data = row
			break
		end
	end

	ngx.say(cjson.encode({ret = 0,msg = "",data = data}))

end


--重置缓存
function _M.clear()
  _M.cache = {}
  _M.update_time = 0
  ngx.say(cjson.encode({ret = 0,msg = "ok"}))
end

function _M:extend(hanlder)
    hanlder['/cow_config/merge_server_config/put'] = self.put		--更新或新增一条数据
	hanlder['/cow_config/merge_server_config/query'] = self.get	--查看指定的合服信息
    hanlder['/cow_config/merge_server_config/clear'] = self.clear	--移除缓存
end

return _M

