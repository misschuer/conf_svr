--世界服日志管理类
local GmLogMgr = class('GmLogMgr')

LOG_TYPE_RECHARGE			= 1			--充值日志
LOG_TYPE_GIFT				= 2			--礼包日志
LOG_TYPE_QQ					= 3			--腾讯日志
LOG_TYPE_NOTICE				= 4			--公告日志
LOG_TYPE_LOCK_ACCOUNT		= 5			--封号日志
LOG_TYPE_GAG				= 6 		--禁言解禁日志
LOG_TYPE_KICKING			= 7			--踢人日志
LOG_TYPE_GMLEVEL			= 8			--gm等级日志
LOG_TYPE_UPDATE_RECHARGE_STATUS = 9		--更新充值状态日志

--构造函数
function GmLogMgr:ctor()
	self.log_path_prefix = os.date("%Y-%m-%d")
	self.file_maps = {}		--{[文件名] = 对应的file句柄,}
end

--校验下文件日期，如果隔天了，那就得把之前的文件句柄close了
function GmLogMgr:checkFileName()
	local prefix = os.date("%Y-%m-%d")
	if prefix ~= self.log_path_prefix then
		--先把之前打开的文件关了
		for file_name, file in pairs(self.file_maps) do
			local start = string.find(file_name, prefix)
			if start ~= nil and file then
				file:close()			
			end			
	    end
	    self.file_maps = {}
		--已经过了一天了
		self.log_path_prefix = prefix
	end	
end

--获得日志文件句柄
function GmLogMgr:getFile(typed)
	local file_name = self:getPath(typed)
	local file = self.file_maps[file_name]
	--缓存里有
	if file then
		--ngx.log(ngx.ERR, string.format("ERROR: getFile cache file  %s", file_name))
		return file
	end
	
	--重新打开文件
	file = io.open(file_name, "a")
	self.file_maps[file_name] = file	--存入缓存
	return file
end

--获得日志文件的路径名
function GmLogMgr:getPath(typed)
	local logname = {
		[LOG_TYPE_RECHARGE] 	= "gm_recharge",
		[LOG_TYPE_GIFT	  ]		= "gm_gift_packs",
		[LOG_TYPE_QQ	  ]		= "gm_qq_config",
		[LOG_TYPE_NOTICE  ]		= "gm_notice",
		[LOG_TYPE_LOCK_ACCOUNT]	= "gm_lock_account",
		[LOG_TYPE_GAG]			= "gm_gag",
		[LOG_TYPE_KICKING]		= "gm_kicking",
		[LOG_TYPE_GMLEVEL]		= "gm_level",
		[LOG_TYPE_UPDATE_RECHARGE_STATUS] = "GM_UPDATE_RECHARGE_STATUS_LOG",
	}
	
	return string.format('data/%s_%d_%s.log', self.log_path_prefix, ngx.worker.pid(), logname[typed])	
end

--写充值日志
function GmLogMgr:writeRechargeLog(account, recharge_id, type, amount, adddate, ret, recharge_success, recharge_fail)
	self:checkFileName()
	local file = self:getFile(LOG_TYPE_RECHARGE)
	if(file)then
		file:write(string.format("%s %s %s %d %d %d %d %s %s\n", os.date("%H:%M:%S"), 
			account, recharge_id, type, amount, adddate, ret, recharge_success, recharge_fail ))		
		file:flush()
	end	
end

--写礼包日志
function GmLogMgr:writeGiftLog(id, ret, status, msg)
	self:checkFileName()
	local file = self:getFile(LOG_TYPE_GIFT)	
	if(file)then		
		file:write( string.format("%s %d %d %d \"%s\"\n", os.date("%H:%M:%S"), id, ret, status, tostring(msg)) )		
		file:flush()
	end	
end

--写qqinfo日志
function GmLogMgr:writeQQLog(server_name, ret, msg)
	self:checkFileName()
	local file = self:getFile(LOG_TYPE_QQ)
	if(file)then		
		file:write( string.format("%s %s %d \"%s\"\n", os.date("%H:%M:%S"), server_name, ret, tostring(msg)) )		
		file:flush()
	end	
end

--写公告日志
function GmLogMgr:writeNoticeLog(server_name, ret, msg)
	self:checkFileName()
	local file = self:getFile(LOG_TYPE_NOTICE)	
	if(file)then		
		file:write( string.format("%s %s %d \"%s\"\n", os.date("%H:%M:%S"), server_name, ret, tostring(msg)) )
		file:flush()
	end	
end

--写封号日志
function GmLogMgr:writeLockAccountLog(server_name, ret, msg)
	self:checkFileName()
	local file = self:getFile(LOG_TYPE_LOCK_ACCOUNT)
	
	if(file)then		
		file:write( string.format("%s %s %d \"%s\"\n", os.date("%H:%M:%S"), server_name, ret, tostring(msg)) )	
		file:flush()
	end	
end

--写禁言解禁日志
function GmLogMgr:writeGagLog(guid, ret, msg)
	self:checkFileName()
	local file = self:getFile(LOG_TYPE_GAG)
	if(file)then		
		file:write( string.format("%s %s %d \"%s\"\n", os.date("%H:%M:%S"), guid, ret, tostring(msg)) )		
		file:flush()
	end	
end

--写踢人日志
function GmLogMgr:writeKickingLog(guid, ret, msg)
	self:checkFileName()
	local file = self:getFile(LOG_TYPE_KICKING)
	if(file)then		
		file:write( string.format("%s %s %d \"%s\"\n", os.date("%H:%M:%S"), guid, ret, tostring(msg)) )	
		file:flush()
	end	
end

--写gm等级日志
function GmLogMgr:writeGmLevelLog(account, gmlevel, ret, msg)
	self:checkFileName()
	local file = self:getFile(LOG_TYPE_GMLEVEL)	
	if(file)then		
		file:write( string.format("%s %s %d %d \"%s\"\n", os.date("%H:%M:%S"), account, gmlevel, ret, tostring(msg)) )	
		file:flush()
	end	
end

--写更新充值订单状态日志
function GmLogMgr:writeGmUpdateRechargeStatus( id, status, msg )
	self:checkFileName()
	local file = self:getFile(LOG_TYPE_UPDATE_RECHARGE_STATUS)	
	if(file)then		
		file:write( string.format("%s %s %s %s\n", os.date("%H:%M:%S"), 
			tostring(id), tostring(status), tostring(msg))  )	
		file:flush()
	end	
end


return GmLogMgr