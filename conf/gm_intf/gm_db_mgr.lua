---------------------------------
---后台相关数据库操作------------
local dbMgr = require 'util.db_access'
require 'sharedDef'

local gm_dbMgr ={}


--获取数据库表对象
function gm_dbMgr:get_tbl( dbname )
	local db = dbMgr.getDBObj('gm_intf')
	--充值库放在gm_recharge.gm_recharge
	if dbname == "gm_recharge" then
		db = dbMgr.getDBObj('gm_recharge')
	end

	if not db then
		return nil
	end
    return db[dbname]
end

--加载gm等级表 GM_LEVEL_TABLE_START = 0	-- 初始化 GM_LEVEL_TABLE_END = 1	-- 已执行
function gm_dbMgr:loadGmLevel()
	local rows = {}
	
	local tbl = self:get_tbl("gm_level")
	if not tbl then
		return rows
	end
	
	local where ={ i_status = GM_LEVEL_TABLE_START } 
	local c = tbl:find( where, {}, 0)
	while c:hasNext() do
		local r = c:next()
		if r and table.nums(r) > 0 then
			table.insert(rows, r)
		end
    end
	
	return rows
end

--更新gm_level表的状态为已执行
function gm_dbMgr:updateGmLevelStatus( ids )
	if #ids == 0 then return end
	
	local tbl = self:get_tbl("gm_level")
	if not tbl then
		return 
	end
	
	local where = { _id = { ["$in"] = ids } }
	local set = {["$set"] = { i_status = GM_LEVEL_TABLE_END}}
	
	local isOk, err = tbl:update(where, set, false, true)

	return isOk, err
end

--加载gm踢人表 KICKING_STATUS_START		=0,		//初始化 KICKING_STATUS_END			=1,		//已踢
function gm_dbMgr:loadGmKicking()
	local rows = {}
	
	local tbl = self:get_tbl("gm_kicking")
	if not tbl then
		return rows
	end
	
	local where ={ i_status = KICKING_STATUS_START } 
	local c = tbl:find( where, {}, 0)
	while c:hasNext() do
		local r = c:next()
		if r and table.nums(r) > 0 then
			table.insert(rows, r)
		end
    end
	
	return rows
end

--更新gm踢人表的状态为已踢
function gm_dbMgr:updateGmKickingStatus( ids )
	if #ids == 0 then return end
	
	local tbl = self:get_tbl("gm_kicking")
	if not tbl then
		return 
	end
	
	local where = { _id = { ["$in"] = ids } }
	local set = {["$set"] = { i_status = KICKING_STATUS_END}}
	
	local isOk, err = tbl:update(where, set, false, true)

	return isOk, err
end

--加载gm禁言，解禁表 GAG_STATUS_START		=0,		//初始化 GAG_STATUS_END			=1,		//已禁言
function gm_dbMgr:loadGmGag()
	local rows = {}
	
	local tbl = self:get_tbl("gm_gag")
	if not tbl then
		return rows
	end
	
	local where ={ i_status = GAG_STATUS_START } 
	local c = tbl:find( where, {}, 0)
	while c:hasNext() do
		local r = c:next()
		if r and table.nums(r) > 0 then
			table.insert(rows, r)
		end
    end
	
	return rows
end

--更新gm禁言，解禁表的状态为已禁言
function gm_dbMgr:updateGmGagStatus( ids )
	if #ids == 0 then return end
	
	local tbl = self:get_tbl("gm_gag")
	if not tbl then
		return 
	end
	
	local where = { _id = { ["$in"] = ids } }
	local set = {["$set"] = { i_status = GAG_STATUS_END}}
	
	local isOk, err = tbl:update(where, set, false, true)

	return isOk, err
end


--加载gm封号表
function gm_dbMgr:loadGmLockAccount( where )
	local rows = {}
	
	local tbl = self:get_tbl("gm_lock_account")
	if not tbl then
		return rows
	end
	
	local wheres = where or { i_status = LOCKING_STATUS_START }
	local c = tbl:find( wheres, {_id = 0}, 0)
	while c:hasNext() do
		local r = c:next()
		if r and table.nums(r) > 0 then
			table.insert(rows, r)
		end
    end
	
	return rows
end

--更新gm封号表的状态
function gm_dbMgr:updateGmLockAccountStatus( ids )
	local tbl = self:get_tbl("gm_lock_account")
	if not tbl then
		return 
	end
	
	for status, id in pairs(ids) do
		local where = { id = { ["$in"] = id } }
		local set = {["$set"] = { i_status = status}}
		tbl:update(where, set, false, true)
	end	
end

--加载gm公告表 
function gm_dbMgr:loadGmNotice( status )
	local rows = {}
		
	local tbl = self:get_tbl("gm_notice")
	if not tbl then
		return rows
	end
	
	--这里加载两种状态的数据 SYSTEM_NOTICE_STATUS_START 和 SYSTEM_NOTICE_STATUS_DELETE
	local status = status or {SYSTEM_NOTICE_STATUS_START, SYSTEM_NOTICE_STATUS_DELETE}
	local where ={ i_status = { ["$in"] = status }}
	local c = tbl:find( where, {_id = 0}, 0)
	while c:hasNext() do
		local r = c:next()
		if r and table.nums(r) > 0 then
			table.insert(rows, r)
		end
    end
	
	return rows
end

--更新gm公告表的状态
function gm_dbMgr:updateGmNoticeStatus( ids )
	local tbl = self:get_tbl("gm_notice")
	if not tbl then
		return 
	end
	
	for status, id in pairs(ids) do
		local where = { id = { ["$in"] = id } }
		local set = {["$set"] = { i_status = status}}		
		tbl:update(where, set, false, true)
	end	
end

--加载qq信息
function gm_dbMgr:loadGmQQInfo( where )
	local rows = {}	
	local tbl = self:get_tbl("gm_qq_config")
	if not tbl then
		return rows
	end
	
	local wheres = where or {i_status = 0}
	local c = tbl:find( wheres, {_id = 0}, 0)
	while c:hasNext() do
		local r = c:next()
		if r and table.nums(r) > 0 then
			table.insert(rows, r)
		end
    end
	
	return rows
end

function gm_dbMgr:updateGmQQInfoStatus( server_names )
	if #server_names == 0 then return end
	
	local tbl = self:get_tbl("gm_qq_config")
	if not tbl then
		return 
	end
	
	local where = { server_name = { ["$in"] = server_names } }
	local set = {["$set"] = { i_status = 1}}
	tbl:update(where, set, false, true)

end

--加载礼包信息
function gm_dbMgr:loadGmGift()
	local rows = {}	
	local tbl = self:get_tbl("gm_gift_packs")
	if not tbl then
		return rows
	end
	
	local now = os.time()
	local where ={ i_status = GIFT_PACKS_STATUS_START, u_end_time = {["$gt"] = now} }
	local c = tbl:find( where, {}, 0)
	while c:hasNext() do
		local r = c:next()
		if r and table.nums(r) > 0 then
			table.insert(rows, r)
		end
    end
	
	return rows
end

--更新礼包状态
function gm_dbMgr:updateGmGiftStatus( ids )
	if #ids == 0 then return end
	
	local tbl = self:get_tbl("gm_gift_packs")
	if not tbl then
		return 
	end
	
	local where = { _id = { ["$in"] = ids } }
	local set = {["$set"] = { i_status = GIFT_PACKS_STATUS_OK}}
	tbl:update(where, set, false, true)

end

--加载充值信息
function gm_dbMgr:loadGmRecharge()
	local rows = {}	
	local tbl = self:get_tbl("gm_recharge")
	if not tbl then
		return rows
	end
	
	local wheres = {}
	wheres['i_status'] = RECHARGE_STATUS_TYPE_START	
	local values = {}
	values['$query'] = wheres
	values['$orderby'] = {u_adddate = 1}
	--local where ={ i_status = RECHARGE_STATUS_TYPE_START }
	local c = tbl:find( values, {}, 0)
	while c:hasNext() do
		local r = c:next()
		if r and table.nums(r) > 0 then
			table.insert(rows, r)
		end
    end
	
	return rows
end

--更新充值信息状态
function gm_dbMgr:updateGmRechargeStatus( ids, val)
	if #ids == 0 then return end
	
	local tbl = self:get_tbl("gm_recharge")
	if not tbl then
		return 
	end
	
	local where = { _id = { ["$in"] = ids }} 
	local set = {["$set"] = val}	
	tbl:update(where, set, false, true)
end


--加载充值信息
function gm_dbMgr:queryGmRechargeStatus(where)
	local tbl = self:get_tbl("gm_recharge")
	if not tbl then
		return
	end
	
	local c = tbl:findOne(where)
	if c then
		return c["i_status"]
	end	
end

--load现金兑换档位配置
function gm_dbMgr:loadGearConf( )
	local rows = {}
	local tbl = self:get_tbl("gear_conf")
	if not tbl then
		return rows
	end
	
	local c = tbl:find( {}, {_id = 0})
	while c:hasNext() do
		local r = c:next()
		if r and table.nums(r) > 0 then
			table.insert(rows, r)
		end
    end
	return rows
end

--load现金兑换地址配置
function gm_dbMgr:loadAddrConf( )
	local rows = {}
	local tbl = self:get_tbl("addr_conf")
	if not tbl then
		return rows
	end

	local c = tbl:find( {}, {_id = 0})
	while c:hasNext() do
		local r = c:next()
		if r and table.nums(r) > 0 then
			table.insert(rows, r)
		end
    end
	return rows
end

--加载激活码
function gm_dbMgr:loadJhm( )
	local rows = {}
	local tbl = self:get_tbl("jhm_code")
	if not tbl then
		return rows
	end

	local c = tbl:find( {}, {_id = 0})
	while c:hasNext() do
		local r = c:next()
		if r and table.nums(r) > 0 then
			table.insert(rows, r)
		end
    end
	return rows
end

--保存激活码
function gm_dbMgr:saveJhm( values )
	local rows = {}
	local tbl = self:get_tbl("jhm_code")
	if not tbl then
		return rows
	end

	tbl:insert(values)
	return rows
end

--load内部扶持列表
--字段:server_name, account, i_status, u_update_time, account_type(0，非内部扶持账号，1,内部扶持账号)
function gm_dbMgr:loadInaccountList( )
	local rows = {}
	local tbl = self:get_tbl("gm_inaccount_list")
	if not tbl then
		return rows
	end
	
	local c = tbl:find( {i_status = 0}, {_id = 0, u_update_time = 0})
	while c:hasNext() do
		local r = c:next()
		if r and table.nums(r) > 0 then
			table.insert(rows, r)
		end
    end
	return rows
end

--update内部扶持列表
--字段:server_name, account, i_status, u_update_time, account_type(0，非内部扶持账号，1,内部扶持账号)
function gm_dbMgr:updateInaccountList( accounts )
	if #accounts == 0 then return end
	
	local tbl = self:get_tbl("gm_inaccount_list")
	if not tbl then
		return 
	end
	
	local where = { account = { ["$in"] = accounts } }
	local set = {["$set"] = { i_status = 1}}
	
	local isOk, err = tbl:update(where, set, false, true)

	return isOk, err
end



return gm_dbMgr