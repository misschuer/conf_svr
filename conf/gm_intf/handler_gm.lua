-----后台相关路由
assert(ngx.shared.mem_locks, "ngx conf 没有配置 共享内存对象 mem_locks")
local http = require "resty.http";
require 'sharedDef'
local dbMgr = require 'gm_intf.gm_db_mgr'
local appAddr = require "cow_config.app_addr"
local logMgr = require("gm_intf.gm_log_mgr").new()

local cjson = require 'cjson'
local router_cls = require 'util.router_map'
local mcurl = require 'mcurl'
local vaildArgs = router_cls.vaildArgs
local lockaccount_cache  = ngx.shared.gmIntf_lockaccount_cache 	--封号表共享缓存
local notice_cache = ngx.shared.gmIntf_notice_cache				--公告表共享缓存
local qqinfo_cache = ngx.shared.gmIntf_qqinfo_cache				--qq_info共享缓存
local jhm_cache = ngx.shared.gmIntf_jhm_cache					--激活码共享缓存

local _M ={
	protocol		= "http",
	method			= "POST",
	update_count = 0,	
	gear_cache = nil,
	addr_cache = nil,
}

--json转换，防崩溃
function  _M.__tryDecode(jsonStr)
	local o = nil
	local status, err = pcall(function (  )
		o = cjson.decode(jsonStr)
	end)
	if not status then
		return nil
	end
	return o
end

function _M.getLockAccountCacheKey(server_name)
	return tostring(server_name)			--直接拿账号做key
end

function _M.getNoticeCacheKey(server_name)
	return tostring(server_name)
end

function _M.getQQInfoCacheKey(server_name)
	return tostring(server_name)
end

--web启动的时候把数据load到缓存
function _M.loadCache()
	--加载封号表到内存
	local classify_by_servername = {}		
	local results = dbMgr:loadGmLockAccount({ i_status = LOCKING_STATUS_RUNNING })	
	local ids = {} 	
	ids[LOCKING_STATUS_END] = {}
	local timenow = os.time()
	for _, info in ipairs(results) do
		if tonumber(info.u_end_time) < timenow then
			--如果已经结束则置成 LOCKING_STATUS_END
			table.insert(ids[LOCKING_STATUS_END], info.id)
		else
			--先按server_name分类
			if not classify_by_servername[info.server_name] then classify_by_servername[info.server_name] = {} end
			table.insert(classify_by_servername[info.server_name], info)
		end
	end
	--以server_name为key进共享缓存
	for server, params in pairs( classify_by_servername ) do
		--ngx.log(ngx.ERR, string.format("ERROR: loadCache server:%s  params%s", server,cjson.encode(params) ))	
		lockaccount_cache:set( _M.getLockAccountCacheKey(server) , cjson.encode(params))
	end
	
	if #ids[LOCKING_STATUS_END] > 0 then
		dbMgr:updateGmLockAccountStatus(ids)
	end
	
	
	--load 公告
	results = dbMgr:loadGmNotice({SYSTEM_NOTICE_STATUS_RUNNING})
	classify_by_servername, ids = {},{}
	ids[SYSTEM_NOTICE_STATUS_GARBAGE] = {}
	for _, info in ipairs(results) do
		if tonumber(info.u_end_time) < timenow then
			--如果已经结束则置成 SYSTEM_NOTICE_STATUS_GARBAGE
			table.insert(ids[SYSTEM_NOTICE_STATUS_GARBAGE], info.id)
		else
			--先按server_name分类
			if not classify_by_servername[info.server_name] then classify_by_servername[info.server_name] = {} end
			table.insert(classify_by_servername[info.server_name], info)
		end
	end
	
	--以server_name为key进共享缓存
	for server, params in pairs( classify_by_servername ) do
		notice_cache:set( _M.getNoticeCacheKey(server) , cjson.encode(params))
	end
			
	if #ids[SYSTEM_NOTICE_STATUS_GARBAGE] > 0 then
		dbMgr:updateGmNoticeStatus(ids)
	end
	
	--qq_info相关 ps:一个server_name只有一条记录
	results = dbMgr:loadGmQQInfo({i_status = 1})
	for _, info in ipairs(results) do
		qqinfo_cache:set( _M.getQQInfoCacheKey(info.server_name) , cjson.encode(info))
	end

	--加载激活码
	results = dbMgr:loadJhm()
	for _, info in ipairs(results) do
		--ngx.log(ngx.ERR, string.format("--------jhm_cache:%s", cjson.encode(info)))
		jhm_cache:set(cjson.encode(info), "1")
	end
end

--后台gm心跳
function _M.update()
	--gm等级表
	_M.updateGmLevel()
	--gm踢人心跳
	_M.updateGmKicking()
	--禁言，解禁心跳
	_M.updateGmGag()
	--封号心跳
	_M.updateGmLockAccount()
	--公告心跳
	_M.updateGmNotice()
	--qq信息心跳
	_M.updateGmQQInfo()
	--礼包心跳
	_M.updateGmGift()
	--充值心跳
	_M.updateGmRecharge()
	--内部扶持账号心跳
	_M.updateGmInaccount()

	_M.update_count = _M.update_count + 1
end

function _M.reload()
	local args = vaildArgs( {"server_names", "type"})
	if not args then return end
	
	local server_names = args["server_names"] or ""
	local server_names_tb = string.split(server_names, ';')		--切割出 server_name
	local server_type = args["type"]
	local cm = mcurl:new()
	if server_type == "logind" then
		--封号相关, 直接从缓存中取出
		for _, server_name in ipairs(server_names_tb) do
			local cache_data = lockaccount_cache:get(server_name)
			if cache_data then
				--ngx.log(ngx.ERR, string.format("ERROR: reload local cache_data:%s", cache_data ))
				local url,res = _M.getPostUrl(server_name,server_type,"/gm_intf/gm_lock_account")
				if(url)then
					cm:add(url,cache_data,function(res, responseCode, value)
						--不需要回调处理
					end,res)
				end
			end
		end
		--qq_info相关
		local results = {}
		for _, server_name in ipairs(server_names_tb) do
			local cache_data = qqinfo_cache:get(server_name)
			if cache_data then
				local param = _M.__tryDecode(cache_data)
				table.insert(results, param)			
			end
		end
		if #results > 0 then
			local url,res = _M.getPostUrl(results[1].server_name,server_type,"/gm_intf/gm_qq_config")
			if(url)then
				cm:add(url,cjson.encode(results),function(res, responseCode, value)
					--不需要回调处理
				end,res)
			end	
		end
	elseif server_type == "appd" then
		--公告相关, 直接从缓存中取出
		for _, server_name in ipairs(server_names_tb) do
			local cache_data = notice_cache:get(server_name)
			if cache_data then
				local params = _M.__tryDecode(cache_data)
				local url,res = _M.getPostUrl(server_name,server_type,"/gm_intf/gm_notice")
				if(url)then
					cm:add(url,cjson.encode(params),function(res, responseCode, value)
						--不需要回调处理
					end,res)
				end	
			end
		end
	end
	cm:perform()	
	ngx.print(cjson.encode({ret=0,msg="ok"}))	
end


--gm等级表心跳
function _M.updateGmLevel(  )
	--local args = vaildArgs( {} ) or {}
	local uri = "/gm_intf/gm_level"
	local results = dbMgr:loadGmLevel()
	local ids, rets = {}, {}
	local cm = mcurl:new()
	for _, info in ipairs(results) do
		local params = {account = info.account, gm_level = info.i_gm_level}
		local url,res = _M.getPostUrl(info.server_name,"logind",uri)
		if(url)then
			cm:add(url,cjson.encode(params),function(res, responseCode, value)		
				local result = _M.__tryDecode(value)
				if(not result)then
					ngx.print("updateGmKicking result is nil ",responseCode,info._id)			
					return
				end
				if(responseCode ~= 200 and responseCode ~= 500)then	--不是游戏服过来的错误
					ngx.print("updateGmKicking responseCode is ",responseCode)		
					return
				end
				result.ret = tonumber(result.ret)
				if result.ret ~= 0 then
					logMgr:writeGmLevelLog(info.account, info.i_gm_level, result.ret, result.msg)
				end
				if result.ret == 0 then
					--gm等级设置成功，修改数据库状态
					table.insert(ids, info._id)
				end
				table.insert(rets, result)
			end,res)
		else
			res.account = info.account
			table.insert(rets, res)
		end
	end
	cm:perform()
	--把执行成功的状态置掉
	dbMgr:updateGmLevelStatus(ids)	
	ngx.print(cjson.encode(rets))	
end

--gm踢人心跳
function _M.updateGmKicking(  )
	--local args = vaildArgs( {} ) or {}
	local uri = "/gm_intf/gm_kicking"
	local results = dbMgr:loadGmKicking()
	local ids,rets = {},{}
	local cm = mcurl:new()
	for _, info in ipairs(results) do
		local params = {guid = info.char_id}
		local url,res = _M.getPostUrl(info.server_name,"logind",uri)
		if(url)then
			cm:add(url,cjson.encode(params),function(res, responseCode, value)		
				local result = _M.__tryDecode(value)
				if(not result)then
					ngx.print("updateGmKicking result is nil ",responseCode,info._id)			
					return
				end
				if(responseCode ~= 200 and responseCode ~= 500)then	--不是游戏服过来的错误
					ngx.print("updateGmKicking responseCode is ",responseCode)		
					return
				end
				result.ret = tonumber(result.ret)
				if result.ret ~= 0 then
					logMgr:writeKickingLog(info.char_id, result.ret, result.msg)
				end		
				if result.ret == 0 then
					--踢人成功，修改数据库状态
					table.insert(ids, info._id)
				end
				table.insert(rets, result)
			end,res)
		else
			res.guid = info.char_id
			table.insert(rets, res)	
		end		
	end
	cm:perform()
	--把执行成功的状态置掉
	dbMgr:updateGmKickingStatus(ids)	
	ngx.print(cjson.encode(rets))	
end

--禁言，解禁心跳
function _M.updateGmGag(  )
	--local args = vaildArgs( {} ) or {}
	local uri = "/gm_intf/gm_gag"
	local results = dbMgr:loadGmGag()
	local ids, rets = {}, {}
	local cm = mcurl:new()
	for _, info in ipairs(results) do
		local params = {guid = info.guid, type = info.i_type, end_time = info.u_end_time}
		local url,res = _M.getPostUrl(info.server_name,"logind",uri)
		if(url)then
			cm:add(url,cjson.encode(params),function(res, responseCode, value)		
				local result = _M.__tryDecode(value)
				if(not result)then
					ngx.print("updateGmGag result is nil ",responseCode,info._id)			
					return
				end
				if(responseCode ~= 200 and responseCode ~= 500)then	--不是游戏服过来的错误
					ngx.print("updateGmGag responseCode is ",responseCode)		
					return
				end
				result.ret = tonumber(result.ret)
				if result.ret ~= 0 then
					logMgr:writeGagLog(info.guid, result.ret, result.msg)
				end		
				if result.ret == 0 then
					--禁言，解禁成功，修改数据库状态
					table.insert(ids, info._id)
				end
				table.insert(rets, result)
			end,res)
		else
			res.guid = info.guid
			table.insert(rets, res)
		end
	end
	cm:perform()
	--把执行成功的状态置掉
	dbMgr:updateGmGagStatus(ids)	
	ngx.print(cjson.encode(rets))	
end

--封号心跳
function _M.updateGmLockAccount(  )
	--local args = vaildArgs( {} ) or {}
	local uri = "/gm_intf/gm_lock_account"
	local results = dbMgr:loadGmLockAccount()
	local classify_by_servername = {}
	--根据server_name分类
	for _, info in ipairs(results) do
		if not classify_by_servername[info.server_name] then classify_by_servername[info.server_name] = {} end
		table.insert(classify_by_servername[info.server_name], info)
	end
	
	--上锁
	local lock = require "resty.lock"
	lock = lock:new("gmIntf_lockaccount_cache")
	local elapsed, err = lock:lock("lockaccount_lock") 	
	if not elapsed then
		ngx.print("updateGmLockAccount failed to lock: ", err)
		return
	end
	local cm = mcurl:new()
	local ids, rets = {}, {}
	ids[LOCKING_STATUS_RUNNING] = {}
	ids[LOCKING_STATUS_END] = {}
	for server, params in pairs(classify_by_servername) do
		--获得缓存数据
		local cache_data = lockaccount_cache:get(server)
		local cache_params = {}
		if cache_data then
			cache_params = _M.__tryDecode(cache_data)
		end
		local url,res = _M.getPostUrl(server,"logind",uri)
		if(url)then
			cm:add(url,cjson.encode(params),function(res, responseCode, value)		
				local result = _M.__tryDecode(value)
				if(not result)then
					ngx.print("updateGmLockAccount result is nil ",responseCode,value)			
					return
				end
				if(responseCode ~= 200)then	--不是游戏服过来的错误
					ngx.print("updateGmLockAccount responseCode is ",responseCode)		
					return
				end
				result.ret = tonumber(result.ret)
				if result.ret ~= 0 then
					logMgr:writeLockAccountLog(server, result.ret, result.msg)
				end
				if result.ret == 0 then
					--取出封号中的ids
					local locking_ids = {}
					if result.locking_ids then locking_ids = string.split(result.locking_ids, ',') end
					--取出结束封号的ids
					local end_locking_ids = {} 
					if result.end_locking_ids then end_locking_ids = string.split(result.end_locking_ids, ',') end
					
					for _, id in ipairs(end_locking_ids) do 
						table.insert(ids[LOCKING_STATUS_END], tonumber(id))
						--缓存里没有直接break
						if not cache_params then break end
						--找到对应的记录删掉				
						for index, cache_info in ipairs(cache_params) do
							if cache_info.id == tonumber(id) then
								--找到执行更新
								cache_params[index] = nil
								break
							end
						end						
					end
					
					for _, id in ipairs(locking_ids) do
						ngx.print("locking_ids id is "..id.."\n")
						table.insert(ids[LOCKING_STATUS_RUNNING], tonumber(id))
						--缓存里没找到就不用删除
						if not cache_params then break end
						for index, cache_info in ipairs(cache_params) do
							if cache_info.id == tonumber(id) then
								--找到执行更新
								cache_params[index] = nil
								break
							end
						end						
					end
					
					for _, info in ipairs(params) do
						ngx.print("params id is \n")
						table.insert(cache_params,info)
					end
					if #cache_params > 0 then
						ngx.print("cache_params id is \n")
						--重新存到共享缓存中
						lockaccount_cache:set( _M.getLockAccountCacheKey(server) , cjson.encode(cache_params))
					end
				end
			end,res)			
		else
			res.server_name = server
			table.insert(rets, res)
		end	
	end
	cm:perform()
	local ok, err = lock:unlock()
    if not ok then
        ngx.print("updateGmLockAccount failed to unlock: ", err)
    end   	
	
	dbMgr:updateGmLockAccountStatus(ids)
	ngx.print(cjson.encode(rets))	
end

--公告心跳
function _M.updateGmNotice(  )
	--local args = vaildArgs( {} ) or {}
	local uri = "/gm_intf/gm_notice"
	local results = dbMgr:loadGmNotice()
	local classify_by_servername = {}
	--根据server_name分类
	for _, info in ipairs(results) do
		if not classify_by_servername[info.server_name] then classify_by_servername[info.server_name] = {} end
		table.insert(classify_by_servername[info.server_name], info)
	end
	
	--上锁
	local lock = require "resty.lock"
	lock = lock:new("gmIntf_notice_cache")
	local elapsed, err = lock:lock("notice_lock") 	
	if not elapsed then
		ngx.print("updateGmNotice failed to lock: ", err)
		return
	end

	local cm = mcurl:new()
	local ids,rets = {},{}
	ids[SYSTEM_NOTICE_STATUS_GARBAGE] = {}
	ids[SYSTEM_NOTICE_STATUS_RUNNING] = {}
	for server, params in pairs(classify_by_servername) do
		--获得缓存数据
		local cache_data = notice_cache:get(server)
		local cache_params = {}
		if cache_data then
			cache_params = _M.__tryDecode(cache_data)
		end
		local url,res = _M.getPostUrl(server,"appd",uri)
		if(url)then
			cm:add(url,cjson.encode(params),function(res, responseCode, value)		
				local result = _M.__tryDecode(value)
				if(not result)then
					ngx.print("updateGmNotice result is nil ",responseCode,value)			
					return
				end
				if(responseCode ~= 200 and responseCode ~= 500)then	--不是游戏服过来的错误
					ngx.print("updateGmNotice responseCode is ",responseCode)		
					return
				end
				result.ret = tonumber(result.ret)
				if result.ret ~= 0 then
					logMgr:writeNoticeLog(server, result.ret, result.msg)
				end
				if result.ret == 0 then
					--取出封号中的ids
					local running_ids = {}
					if result.running_ids then running_ids = string.split(result.running_ids, ',') end
					--取出结束封号的ids
					local end_ids = {} 
					if result.end_ids then end_ids = string.split(result.end_ids, ',') end
					--已经结束的话删除缓存数据
					for _, id in ipairs(end_ids) do 
						table.insert(ids[SYSTEM_NOTICE_STATUS_GARBAGE], tonumber(id))
						if not cache_params then
							break --缓存里没有直接break
						end
						--找到对应的记录删掉			
						for index, cache_info in ipairs(cache_params) do
							if cache_info.id == tonumber(id) then
								--找到执行更新
								cache_params[index] = nil
								break
							end
						end								
					end
					--运行中的话，将已有的缓存数据删除后，全部加入
					for _, id in ipairs(running_ids) do 
						table.insert(ids[SYSTEM_NOTICE_STATUS_RUNNING], tonumber(id))
						if not cache_params then break end
						for index, cache_info in ipairs(cache_params) do
							if cache_info.id == tonumber(id) then
								--找到执行更新
								cache_params[index] = nil
								break
							end
						end									
					end
					--将数据全部插入，前面已经删除过了，不会重复
					for _, info in ipairs(params) do
						--存到共享缓存
						table.insert(cache_params, info)
					end
				end
				result.server_name = server
				table.insert(rets, result)
				if #cache_params > 0 then
					--重新存到共享缓存中
					notice_cache:set( _M.getNoticeCacheKey(server) , cjson.encode(cache_params))
				end
			end,res)
		else
			table.insert(rets, res)
		end
	end
	cm:perform()
	local ok, err = lock:unlock()
    if not ok then
        ngx.say("updateGmNotice failed to unlock: ", err)
    end   	
	
	dbMgr:updateGmNoticeStatus(ids)
	ngx.print(cjson.encode(rets))
end

--qq信息心跳
function _M.updateGmQQInfo(  )
	--local args = vaildArgs( {} ) or {}
	local uri = "/gm_intf/gm_qq_config"
	local results = dbMgr:loadGmQQInfo()	
	--上锁
	local lock = require "resty.lock"
	lock = lock:new("gmIntf_qqinfo_cache")
	local elapsed, err = lock:lock("qqinfo_lock") 		
	if not elapsed then
		ngx.print("qqinfo_lock failed to lock: ", err)
		return
	end
	local cm = mcurl:new()
	local server_names, rets = {}, {}
	for _, info in ipairs(results) do
		local params = {qq_info = info.qq_info,server_name = info.server_name}
		local url,res = _M.getPostUrl(info.server_name,"logind",uri)
		if(url)then
			cm:add(url,cjson.encode(params),function(res, responseCode, value)		
				local result = _M.__tryDecode(value)
				if(not result)then
					ngx.print("updateGmQQInfo result is nil ",responseCode,info._id)			
					return
				end
				if(responseCode ~= 200 and responseCode ~= 500)then	--不是游戏服过来的错误
					ngx.print("updateGmQQInfo responseCode is ",responseCode)		
					return
				end
				result.ret = tonumber(result.ret)
				if result.ret ~= 0 then
					logMgr:writeQQLog(info.server_name, result.ret, result.msg)
				end		
				if result.ret == 0 then
					--成功
					table.insert(server_names, info.server_name)
					--存进缓存
					qqinfo_cache:set( _M.getQQInfoCacheKey(info.server_name) , cjson.encode(info))
				end
				result.server_name = info.server_name
				table.insert(rets, result)
			end,res)
		else
			table.insert(rets, res)
		end
	end
	cm:perform()
	local ok, err = lock:unlock()
    if not ok then
        ngx.say("updateGmQQInfo failed to unlock: ", err)
    end   	
	dbMgr:updateGmQQInfoStatus(server_names)
	if not isDispatch then
		--部分发的话把错误返回下
		ngx.print(cjson.encode(rets))	
	end
end

--礼包心跳
function _M.updateGmGift(  )
	--local args = vaildArgs( {} ) or {}
	local uri = "/gm_intf/gm_gift_packs"
	local results = dbMgr:loadGmGift()
	--ngx.log(ngx.ERR, string.format("ERROR: updateGmGift #results %d", #results))
	local ids,rets = {},{}
	local cm = mcurl:new()
	for _, info in ipairs(results) do
		local params = {id = info.id, gift_type = info.i_gift_type, audience_type = info.i_audience_type, start_time = info.u_start_time,
				end_time = info.u_end_time, gift_name = info.gift_name, gift_desc = info.gift_desc, item_config = info.s_item_config, to_id = info.to_id }
		local url,res = _M.getPostUrl(info.server_name,"appd",uri)
		if(url)then
			cm:add(url,cjson.encode(params),function(res, responseCode, value)		
				local result = _M.__tryDecode(value)
				if(not result)then
					ngx.print("updateGmGift result is nil ",responseCode,info._id)			
					return
				end
				if(responseCode ~= 200 and responseCode ~= 500)then	--不是游戏服过来的错误
					ngx.print("updateGmGift responseCode is ",responseCode)		
					return
				end
				result.ret = tonumber(result.ret)
				result.status = tonumber(result.status) or GIFT_PACKS_STATUS_START
				if result.ret ~= 0 then
					logMgr:writeGiftLog(info.id, result.ret, result.status, result.msg)
				end
				if result.ret == 0 and result.status ~= GIFT_PACKS_STATUS_START then
					table.insert(ids, info._id)
				end
				result.id = info.id
				table.insert(rets, result)
			end,res)
		else
			table.insert(rets, res)
		end
	end
	cm:perform()
	--把执行成功的状态置掉
	dbMgr:updateGmGiftStatus(ids)
	ngx.print(cjson.encode(rets))	
end

local RECHARGE_RESLUT_SUCCED				= 0		--成功
local RECHARGE_RESLUT_REPATED				= 1 	--重复充值
local RECHARGE_RESLUT_INSUFFICIENT			= 2 	--余额不足，扣费失败
local RECHARGE_RESLUT_EXCEPTION				= 3 	--充值过程中，游戏服代码逻辑出现异常
local RECHARGE_RESLUT_OFFLINE				= 4 	--玩家不在线
local RECHARGE_RESLUT_OFFLINE_SUCCEED		= 5 	--充值时玩家不在线，重新登录以后充值成功
local RECHARGE_RESLUT_OFFLINE_REPATED		= 6 	--充值时玩家不在线，重新登录以后发现重复充值
local RECHARGE_RESLUT_OFFLINE_INSUFFICIENT	= 7 	--充值时玩家不在线，重新登录以后余额不足，扣费失败

--充值心跳
function _M.updateGmRecharge(  )
	--local args = vaildArgs( {} ) or {}
	--上锁
	local lock = require "resty.lock"
	lock = lock:new("gmIntf_recharge_cache")
	local elapsed, err = lock:lock("recharge_lock")
	if not elapsed then
		ngx.print("updateGmRecharge failed to lock: ", err)
		return
	end
	local uri = "/gm_intf/gm_recharge"
	local results = dbMgr:loadGmRecharge()
	local ids, repeat_ids, rets, order_posting, noonline_ids, error_ids, invalid_url, giveup_ids = {},{},{},{},{},{},{},{}
	local nowtime, index = os.time(), 0
	local cm = mcurl:new()
	for i, info in ipairs(results) do
		if i % 20 == 0 then
			index = 0			--执行了先去掉
			dbMgr:updateGmRechargeStatus(order_posting,{i_status = RECHARGE_STATUS_TYPE_RUNMING, u_update_time = nowtime})
			order_posting = {}
			cm:perform()		--先把之前的99条先执行了
			cm = mcurl:new()   	--重新new
		end
		index = i
		local params = {account = info.account, recharge_id = info._id, type = info.i_type, amount = info.i_amount, adddate = info.u_adddate}
		local url,res = _M.getPostUrl(info.server_name,"appd",uri)
		if(url)then
			local post_str = cjson.encode(params)
			table.insert(order_posting, info._id)
			ngx.log(ngx.ERR, "updateGmRecharge params "..post_str)		--每一单都写一下错误日志
			cm:add(url,post_str,function(res, responseCode, value)		
				local result = _M.__tryDecode(value)
				if(not result)then
					table.insert(invalid_url, info._id)
					ngx.print(" updateGmRecharge result is nil "..responseCode.." post_str "..post_str)			
					return
				end
				if(responseCode ~= 200 and responseCode ~= 500)then	--不是游戏服过来的错误
					ngx.print("updateGmRecharge responseCode is ",responseCode)		
					return
				end
				result.ret = tonumber(result.ret)				
				if result.ret == RECHARGE_RESLUT_SUCCED then
					table.insert(ids, info._id)		      		--订单处理成功
				elseif result.ret == RECHARGE_RESLUT_REPATED then
					table.insert(repeat_ids, info._id)			--订单已处理过了
				elseif result.ret == RECHARGE_RESLUT_INSUFFICIENT then
					table.insert(giveup_ids, info._id)			--扣费失败，订单失效
				elseif result.ret == RECHARGE_RESLUT_EXCEPTION then
					table.insert(error_ids, info._id)			--订单出错，加钱或者扣钱失败了
				elseif result.ret == RECHARGE_RESLUT_OFFLINE then
					table.insert(noonline_ids, info._id)		--订单离线状态
				end
				if result.ret ~= RECHARGE_RESLUT_SUCCED then
					--没成功写下日志
					logMgr:writeRechargeLog(info.account, info._id, info.i_type, info.i_amount, info.u_adddate, result.ret, result.status, result.msg)				
				end				
				result.account = info.account
				result.recharge_id = info._id
				table.insert(rets, result)				
			end,res)		
		else
			table.insert(rets, res)
		end
	end
	if index ~= 0 then
		dbMgr:updateGmRechargeStatus(order_posting,{i_status = RECHARGE_STATUS_TYPE_RUNMING, u_update_time = nowtime})		
		cm:perform()
	end
	
	local ok, err = lock:unlock()
	if not ok then		
		ngx.print("updateGmRecharge failed to unlock: ", err)
	end   	
	--把执行成功的状态置掉		
	dbMgr:updateGmRechargeStatus(ids, {i_status = RECHARGE_STATUS_TYPE_END, ret = RECHARGE_RESLUT_SUCCED, u_update_time = nowtime})	
	dbMgr:updateGmRechargeStatus(repeat_ids, {i_status = RECHARGE_STATUS_TYPE_END, ret = RECHARGE_RESLUT_REPATED, u_update_time = nowtime})
	dbMgr:updateGmRechargeStatus(noonline_ids, {i_status = RECHARGE_STATUS_TYPE_OUTLINE, ret = RECHARGE_RESLUT_OFFLINE, u_update_time = nowtime})
	dbMgr:updateGmRechargeStatus(error_ids, {i_status = RECHARGE_STATUS_TYPE_ERROR, ret = RECHARGE_RESLUT_EXCEPTION, u_update_time = nowtime})
	dbMgr:updateGmRechargeStatus(invalid_url, {i_status = RECHARGE_STATUS_TYPE_POSTURL_INVALID, u_update_time = nowtime})
	dbMgr:updateGmRechargeStatus(giveup_ids,{i_status = RECHARGE_STATUS_TYPE_GIVEUP, ret = RECHARGE_RESLUT_INSUFFICIENT, u_update_time = nowtime})
	ngx.print(cjson.encode(rets))	
end

--更新某一订单的状态
function _M.updateRechargeStatus(  )
	local args = vaildArgs( {"id", "ret"} )
	if not args then return end
	
	local ret = tonumber(args["ret"])
	local status = RECHARGE_STATUS_TYPE_END
	if ret ~= RECHARGE_RESLUT_OFFLINE_SUCCEED then
		if ret == RECHARGE_RESLUT_OFFLINE_INSUFFICIENT then
			status = RECHARGE_STATUS_TYPE_GIVEUP
		else
			status = RECHARGE_STATUS_TYPE_ERROR
		end
	end
	local ids = {tostring(args["id"])}
	dbMgr:updateGmRechargeStatus(ids, {i_status = status, ret = ret, nowtime = os.time()})
	logMgr:writeGmUpdateRechargeStatus(args["id"], status, args["msg"])	--写文本日志
	ngx.print(cjson.encode({id = args["id"], ret=0, msg="success"}))
end

--查询充值订单状态
function _M.queryRechargeStatus(  )
	local args = vaildArgs( {"id"} )
	if not args then return end

	local where = {_id=tostring(args["id"])}
	local status = dbMgr:queryGmRechargeStatus(where)
	local rep = {ret = 1, msg = "not find recharge_id "..args["id"], status = -1}
	if status then
		rep = {ret = 0, msg = "success recharge_id "..args["id"], status = status}
	end
	ngx.print(cjson.encode(rep))
end


--测试
function _M.updateGmTest()
	--local args = vaildArgs( {} ) or {}
	local uri = "/gm_intf/gm_test"
	local cm = mcurl:new()
	local sum = 0
	for i = 1, 1000  do
		local url ,res= "http://192.168.30.11:30080/gm_intf/gm_test"
		local params = "count="..i
		if(url)then
			cm:add(url,i,function(res, responseCode, value)		
				local result = _M.__tryDecode(value)
				if(not result)then
					ngx.print("error ",i)
					return
				end
				if(responseCode ~= 200)then	--不是游戏服过来的错误
					ngx.print("updateGmRecharge responseCode is ",responseCode)		
					return
				end
				result.status = tonumber(result.status)
				
				sum = sum + result.status
			end,res)		
		end
	end
	cm:perform()
	ngx.print("updateGmTest count is ",count) 
end

function _M.GetGmTest()
	local args = vaildArgs( {} ) or {}
	ngx.print("get gm test "..table.concat(args, ','))
	logMgr:writeQQLog("1", 1, table.concat(args, ','))
	local cache_params = _M.__tryDecode(args.data)
	local count = cache_params.count
	if(not count)then
		ngx.print("get gm test "..count.." \n")
	end
end

--获得现金兑换档位配置
function _M.getGearConf()
	--缓存有则直接下发
	local response = {}
	if _M.gear_cache then 
		ngx.print(_M.gear_cache)
		--ngx.log(ngx.ERR, string.format("-------->getGearConf cache %s ", _M.gear_cache))
		return
	end
	--缓存不存在则load库
	local results = dbMgr:loadGearConf()
	if #results == 1 then
		response.ret = 0
		response.gear_conf = results[1]
		_M.gear_cache = cjson.encode(response)				--放入缓存
		--ngx.log(ngx.ERR, string.format("-------->getGearConf %s ", _M.gear_cache))
		ngx.print(_M.gear_cache)
		return
	end

	response.ret = 1
	response.gear_conf_count = #results
	response.msg = "not find or too many conf!"				--要么没有，要么库里有不止一条记录
	ngx.print(cjson.encode(response))
end

--获得现金兑换地址配置
function _M.getAddrConf()
	--缓存有则直接下发
	local response = {}
	if _M.addr_cache then
		--ngx.log(ngx.ERR, string.format("-------->getAddrConf cache %s ", _M.addr_cache))
		ngx.print(_M.addr_cache)
		return
	end
	--缓存不存在则load库
	local results = dbMgr:loadAddrConf()
	if #results == 1 then
		response.ret = 0
		response.addr_conf = results[1]
		_M.addr_cache = cjson.encode(response)				--放入缓存
		--ngx.log(ngx.ERR, string.format("-------->getAddrConf %s ", _M.addr_cache))
		ngx.print(_M.addr_cache)
		return
	end

	--ngx.log(ngx.ERR, string.format("-------->getAddrConf error "))
	response.ret = 1
	response.addr_conf_count = #results
	response.msg = "not find or too many conf!"				--要么没有，要么库里有不止一条记录
	ngx.print(cjson.encode(response))
end

--查询激活码是否存在
function _M.queryJhmCode()
	local args = vaildArgs( {"code", "type", "guid"})
	if not args then return end

	local response = {}
	local param = {code = args["code"], i_type = tonumber(args["type"])}
	--ngx.log(ngx.ERR, string.format("--------jhm_cache query:%s", cjson.encode(param)))
	if jhm_cache:get(cjson.encode(param)) then
		--直接判断共享缓存是否已有
		response.ret = 0
		response.msg = "ok"
		response.guid = args["guid"]
		response.code = args["code"]
		response.type = tonumber(args["type"])
		ngx.print(cjson.encode(response))
		return
	end

	response.ret = 1
	response.msg = "fail"
	response.guid = args["guid"]	--guid原样返回
	response.code = args["code"]
	response.type = tonumber(args["type"])	
	ngx.print(cjson.encode(response))	
end

--保存激活码
function _M.saveJhmCode()
	local args = vaildArgs( {"code", "type", "guid"})
	if not args then return end

	local values = {code = args["code"], i_type = tonumber(args["type"])}
	dbMgr:saveJhm(values)
	jhm_cache:set(cjson.encode(values), "1")
	ngx.print(cjson.encode({ret = 0, msg = "ok", guid = args["guid"], code = args["code"], type = args["type"]}))
end

--内部扶持号心跳
function _M.updateGmInaccount()
	local uri = "/gm_intf/gm_inaccount_list"
	local results = dbMgr:loadInaccountList()
	local classify_by_servername = {}
	--根据server_name分类
	for _, info in ipairs(results) do
		if not classify_by_servername[info.server_name] then classify_by_servername[info.server_name] = {} end
		table.insert(classify_by_servername[info.server_name], info)
	end

	local success_account, cm = {}, mcurl:new()
	for server,params in pairs(classify_by_servername) do
		local url,res = _M.getPostUrl(server,"appd",uri)		
		if url then
			cm:add(url,cjson.encode(params),function(res, responseCode, value)		
				local result = _M.__tryDecode(value)
				if(not result)then
					ngx.print("updateGmInaccount result is nil "..responseCode.." "..value)			
					return
				end
				if(responseCode ~= 200)then	--不是游戏服过来的错误
					ngx.print("updateGmInaccount responseCode is "..responseCode)		
					return
				end
				result.ret = tonumber(result.ret)				
				if result.ret == 0 then
					--处理成功了
					for _,account in ipairs(result.success_account) do
						table.insert( success_account, account )
					end					
				end
			end,res)
		end
	end

	cm:perform()
	dbMgr:updateInaccountList(success_account)
	local str = table.concat(success_account, ",")
	ngx.print("updateGmInaccount success:"..str)
end

--获取推送地址
function _M.getPostUrl(server_name,server_type,uri)
	local data = appAddr.getCache(server_name, server_type)	--缓存地址要是没找到那就不处理了
	local res = {ret = -1, msg = "not find ipport for "..server_name}
	local url 
	if(not data)then 
		return url,res
	end
	url = "http://"..data.host_port..uri	
	return url
end

function _M:extend(hanlder)
    --hanlder['/gm_intf/update'] = self.update
	hanlder['/gm_intf/reload'] = self.reload		--数据重发
	--分表的update(load库处理)
	hanlder['/gm_intf/update_gm_level'] = self.updateGmLevel
	hanlder['/gm_intf/update_gm_kicking'] = self.updateGmKicking
	hanlder['/gm_intf/update_gm_gag'] = self.updateGmGag
	hanlder['/gm_intf/update_gm_lock_account'] = self.updateGmLockAccount
	hanlder['/gm_intf/update_gm_notice'] = self.updateGmNotice
	hanlder['/gm_intf/update_gm_qq_config'] = self.updateGmQQInfo
	hanlder['/gm_intf/update_gm_gift_packs'] = self.updateGmGift
	hanlder['/gm_intf/update_gm_recharge'] = self.updateGmRecharge
	--hanlder['/gm_intf/update_gm_test'] = self.updateGmTest
	--hanlder['/gm_intf/gm_test'] = self.GetGmTest	
	--hanlder['/gm_intf/get_gear_conf'] = self.getGearConf
	--hanlder['/gm_intf/get_addr_conf'] = self.getAddrConf
	hanlder['/gm_intf/query_jhm_code'] = self.queryJhmCode
	hanlder['/gm_intf/save_jhm_code'] = self.saveJhmCode
	hanlder['/gm_intf/update_gm_inaccount_list'] = self.updateGmInaccount
	hanlder['/gm_intf/update_recharge_status'] = self.updateRechargeStatus
	hanlder['/gm_intf/query_recharge_status'] = self.queryRechargeStatus
end

return _M

