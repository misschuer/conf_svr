local db = require 'util.db_access'

local router_cls = require 'util.router_map'
local getArgs = router_cls.getArgs

local _M = {}

--[[

--表结构注释
> use oper_tool
> db.server_info.findOne()
{
        "_id" : "1",
        "branch" : "7711",
        "domain" : "m1.tianshu.game2.com.cn",
        "game_id" : "1",
        "git_version" : "",
        "i_run_status" : 3,
        "i_server_type" : 0,
        "id" : NumberLong(1),
        "login_key" : "IZlAQBuRrqO2M6BfBOHcZ1QtkftEVugr",
        "merge_server_names" : "",
        "params" : "Y,Y,3000",
        "path" : "/home/game2_1",
        "pid" : "2",
        "s_test_type" : "1",
        "server_name" : "2_1",
        "sid" : "1",
        "u_install_tm" : NumberLong(1427364061),
        "u_last_update_tm" : NumberLong(1436585295)
}

--]]

function _M.auth_key ()
    local qs = getArgs()
    local server_name = qs['server_name']
    if not server_name or server_name == '' then
        ngx.say(-1)
        ngx.exit(ngx.HTTP_BAD_REQUEST)
        return
    end

    --拆出pid吧，目前都是全平台统一的,所以只缓存平台为key的密钥
    local strs = string.split(server_name, '_')
    local pid = strs[1]

    --缓存表里面找一下
    local v = _M.cache_[p] 
    if v ~= nil then return v end
    
    --还没有缓存的去库里面搜索一下
    local where = {}
    where.server_name = server_name
    local o = db:getDB('oper_tool').server_info:findOne(where)
    if c == nil then 
        ngx.say(-2)
        ngx.exit(ngx.HTTP_NOT_FOUND)
        return
    end

    --加入缓存
    v = o.login_key
    _M.cache_[pid] = v
    ngx.print(v)
end


function _M:extend(hanlder)
    hanlder['/conf_helper/auth_key'] = _M.auth_key
end

return _M

