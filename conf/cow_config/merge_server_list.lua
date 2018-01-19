local db = require 'util.db_access'

local router_cls = require 'util.router_map'
local getArgs = router_cls.getArgs

local _M = {}

function _M.get ()
end

function _M.list()
end

function _M:extend(hanlder)
    hanlder['/cow_conf/merge_server_list/get'] = self.get
    hanlder['/cow_conf/merge_server_list/list'] = self.list
end

return _M

