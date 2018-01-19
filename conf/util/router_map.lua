local router_map = {}
local router_map_mt = {__index = router_map}

local cjson = require 'cjson'

function router_map.new( m )
	local o = {}
	setmetatable(o,router_map_mt)
	if o.ctor then
		o:ctor(m)
	end
	return o
end

--验证是否可执行
local function __isCallable(callback)
	local tc = type(callback)
	if tc == 'function' then return true end
	if tc == 'table' then
		local mt = getmetatable(callback)
		return type(mt) == 'table' and type(mt.__call) == 'function'
	end
	return false
end

--构造函数来了
function router_map:ctor( m )
	self.hanlders = {}
	for uri,hanlder in pairs(m) do
		self:addHanlder(uri,hanlder)
	end
end

function router_map:addHanlder( str, callback, params )
	assert(__isCallable(callback), "callback must be a function")

	local hanlder = {}
	hanlder.str = str
	hanlder.callback = callback
	hanlder.args = params or {}
	self.hanlders[str] = hanlder
end

function router_map:doWork( str )
	if not str then
		str = ngx.var.uri
	end

	--空字符串为默认处理函数,如果找不到对应则找一下默认函数
	local hanlder = self.hanlders[str] or self.hanlders['']
	if hanlder then
		return hanlder.callback(unpack(hanlder.args))
	end
	return false
end

function router_map.getArgs()
    --获取参数的值  
    local args = nil
    if "GET" == ngx.var.request_method then  
        --curl "127.0.0.1:8080/app?a=1&b=2&d=3"
        args = ngx.req.get_uri_args()  
        --args = ngx.var.args
    elseif "POST" == ngx.var.request_method then  
        --curl -d "a=1&b=2&c=3" "127.0.0.1:8080/app"
        ngx.req.read_body()  
        args = ngx.req.get_post_args()
    end  

    return args
end

--验证是否拥有所有必填参数
function router_map.vaildArgs(vaild_Args)
	local args = router_map.getArgs()
	for i=1,#vaild_Args do
	    if args[vaild_Args[i]] == nil or args[vaild_Args[i]] =="" then
			ngx.say(cjson.encode({ret=1,msg=vaild_Args[i].."参数不能为空"}))
			return nil
		end
	end

	return args
end

return router_map

