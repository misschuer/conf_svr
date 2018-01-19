--游戏配置请求
local cjson = require 'cjson'
local router_cls = require 'util.router_map'
local vaildArgs = router_cls.vaildArgs
local dbMgr = require 'util.db_access'

local _M ={
	game_config_cache = {}, 		--按server_name缓存
	last_load_cache_time = 0,		--最后一次加载缓存
	load_cache_internal = 60,		--加载缓存间隔
}

--获取数据库表对象
function _M.get_tbl( dbname )
	local db = dbMgr.getDBObj('server')		
	if not db then
		return nil
	end
    return db[dbname]
end

--load配置
function _M.loadGameConfig( server_name )
	_M.last_load_cache_time = os.time()
	local tbl = _M.get_tbl('game_config')
	if not tbl then	return end

	local rows = {}
	local c = tbl:find({server_name = server_name}, {_id = 0})
	while c:hasNext() do
		local r = c:next()
		if r and table.nums(r) > 0 then
			table.insert(rows, r)
		end
    end

    if #rows > 0 then
		_M.game_config_cache[server_name] = rows
	end
end



--获得游戏配置
function _M.getGameConfig( )
	local args = vaildArgs({"server_name"})
	if not args then return end

	local timenow = os.time()
	if timenow - _M.last_load_cache_time > _M.load_cache_internal then
		--重load到缓存
		_M.loadGameConfig(args["server_name"])
	end

	local param = _M.game_config_cache[args["server_name"]] or {}
	if #param == 0 then
		ngx.print(cjson.encode({ret = 1, msg = "not find config!"}))
	else
		ngx.print(cjson.encode({ret = 0, msg = "ok", game_config = param}))
	end
end

function _M:extend(hanlder)
    hanlder['/server/get_game_config'] = self.getGameConfig		--获得游戏配置
	
end
return _M