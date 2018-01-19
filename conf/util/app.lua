
handler_map = handler_map or {}

--默认处理函数
handler_map['']  = function ()
    ngx.say('oh,no!')
    --ngx.exit(404)
end

--初始化路由表
local router_cls = require 'util.router_map'
local router = router or router_cls.new(handler_map)

if router:doWork() == true then
	ngx.exit(200)
end

