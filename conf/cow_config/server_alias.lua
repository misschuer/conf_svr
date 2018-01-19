
local dbMgr = require 'util.db_access'

local router_cls = require 'util.router_map'
local getArgs = router_cls.getArgs


local _M = {
    cache = {},
    update_time = 0
}
--{server_name:""}

function _M.loadCache()
    local tbl = dbMgr.getDBObj('cow_config').server_alias
    local c = tbl:find()
    while c:hasNext() do
        local r = c:next()
        _M.cache[r.server_name] = r.alias
    end
end

function _M.get()
    local query_strs = getArgs()
    local server_name = query_strs["server_name"]

    --相当的查询没有
    if not server_name then
        ngx.say(-1)
        ngx.exit(ngx.HTTP_BAD_REQUEST)
    end

    --如果缓存表里面存在则直接返回
    local v = _M.cache[server_name] 
    if v then
        ngx.print(v)
        return
    end
    
    --如果缓存表里面找不到则从配置表里面读
    local now = os.time() 
    if _M.update_time + 60*10 < now then
        _M.loadCache()
        _M.update_time = now
    end

    local v = _M.cache[server_name] 
    if v then
        ngx.print(v)
        return
    else
        ngx.say(-2)
    end
end

function _M.clear()
    _M.cache = {}
    ngx.say("ok")
end

function _M:extend(hanlder)
    hanlder['/cow_config/server_alias/get'] = self.get
    hanlder['/cow_config/server_alias/clear'] = self.clear
end

return _M

