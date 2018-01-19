
local dbMgr = require 'util.db_access'

local router_cls = require 'util.router_map'
local getArgs = router_cls.getArgs

local default_conf_map = {
    showhand_server = '',--'showhand.tianshu.game2.com.cn:2500',       --五张牌地址及端口
    world_server = '',--'61.160.234.177:2500',          --世界服网络地址
    wjlt_web_url = '',--'wujiang.tianshu.game2.com.cn',          --武将擂台地址
}

local _M = {}

--用于存储更新时间
_M.update_time = 0

--数据库里面的配置项,如果是平台性配置,优先级如下：
--key < key_pid < key_pid_sid
_M.conf_table_in_db = _M.conf_table_in_db or {}


--取值规则
--3）web的默认值
function get_value(pid, sid, key)
    ----1）7711分支特殊处理 特殊判断
    --if (pid == 2 and sid == 1) or pid == 12 then
    --    local conf7711 = {}
    --    local v = conf7711[key]
    --    return v
    --end

    --2）判断是否从数据库刷新
    --key < key_pid < key_pid_sid
    --判断一下是否需要刷新,一个小时更新一次
    local now = os.time()
    if _M.update_time + 60*60 < now then
        _M.update_time = now
        _M.loadCache()
    end

    --现在可以从数据库的存储表里面获得数据了
    local conf_table_in_db= _M.conf_table_in_db
    v = conf_table_in_db[key ..'|'.. pid ..'|'.. sid]
        or conf_table_in_db[key ..'|'.. pid ]
        or conf_table_in_db[key]

    if v then return v end

    --TODO:也许不该在这里配置默认配置,否则可能导致测试环境用到正式环境的数据
    return default_conf_map[key]
end

--如果字符串为空则返回nil
function tonil(s)
    if not s then return s end
    return s == '' and nil or s
end


function _M.get(...)
    local query_strs = getArgs()
    local pid, sid, key = tonil(query_strs['pid']),tonil(query_strs['sid']),tonil(query_strs['key'])

    if pid == nil or sid == nil or key == nil then
        ngx.say(-1)
        ngx.exit(ngx.HTTP_BAD_REQUEST)
        return
    end

    local v = get_value(pid, sid, key)
    if v == nil then
        ngx.say(-2)
        ngx.exit(ngx.HTTP_NOT_FOUND)
        return
    end
    ngx.print(v)
end

--仅用于调试目的,所有的键列表
function _M.list(...)
    local query_strs = getArgs()
    local pid, sid = tonil(query_strs['pid']), tonil(query_strs['sid'])

    table.foreach(default_conf_map,function(key, value)
        if pid and sid then
            local v = get_value(pid, sid, key)
            ngx.say(key, '\t:', v)
        else
            ngx.say(key, '\t:', value)
        end
    end)
end

--清空缓存
function _M.clear()
    _M.conf_table_in_db  = {}
    _M.update_time = 0
end

--表结构
--[[cow_config.server_config.{
    pid:2,
    sid:1,
    key:'showhand_server',
    value: 'showhand.tianshu.game2.com.cn:2500'}
--]]
function _M.loadCache()
    local self = _M
    self.conf_table_in_db  = {}
    local db = dbMgr.getDBObj('cow_config')
    local tbl = db.server_config
    local c = tbl:find()
    while c:hasNext() do
        local r = c:next()
        local key, pid, sid, value = r.key or '', r.pid or '', r.sid or '',r.value or ''
        if key ~= '' then
            --key < key_pid < key_pid_sid
            if  pid == '' and sid == '' then
                self.conf_table_in_db[key] = value
            elseif pid ~= '' and sid == '' then
                self.conf_table_in_db[key .. '|' .. pid] = value
            else
                self.conf_table_in_db[key .. '|' .. pid .. '|' .. sid] = value
            end
        end
    end
end

function _M:extend(hanlder)
    hanlder['/cow_config/game_config/get'] = self.get
    hanlder['/cow_config/game_config/list'] = self.list
    hanlder['/cow_config/game_config/clear'] = self.clear
end

return _M

