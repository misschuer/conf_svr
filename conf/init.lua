
local handler_map = handler_map or {}
local _M = require('cow_config.game_config'):extend(handler_map)
 _M = require('cow_config.server_alias'):extend(handler_map)
 _M = require('cow_config.app_addr')
 _M:extend(handler_map)
 _M.loadCache()
 _M = require('cow_config.merge_server_config'):extend(handler_map)
 _M = require('cow_config.addr_info')
 _M:extend(handler_map)

 _M = require('gm_intf.handler_gm')
 _M:extend(handler_map)
 _M.loadCache()

 _M = require('server.handler_game_config')
 _M:extend(handler_map)

return handler_map

