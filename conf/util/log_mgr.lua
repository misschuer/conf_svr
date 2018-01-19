
local logMgr = {}
require 'util.functions'

----------------------------------------------------------
--保存订单兑换信息
function logMgr:writeOrderInfo(order_info)
--print("writeRegInfo begin")	
	local dir = "data/"..os.date("%Y-%m").."_special_drop_orders_log.data"
	local file = io.open(dir,"a+")
	if file then
		local info = os.time().." "..tostring(order_info._id).." "..tostring(order_info.guid).." "..tostring(order_info.money).." "..tostring(order_info.server_name).." "..tostring(order_info.time_expired).."\n"
		file:write(info)
		file:close()
	end			
end

function logMgr:writeDebugInfo(info)
--print("writeRegInfo begin")	
	local dir = "data/".."_debug_log.data"
	local file = io.open(dir,"a+")
	if file then
		--local info = os.time().." "..tostring(order_info._id).." "..tostring(order_info.guid).." "..tostring(order_info.money).." "..tostring(order_info.server_name).." "..tostring(order_info.time_expired).."\n"
		file:write(info)
		file:close()
	end			
end


return logMgr

