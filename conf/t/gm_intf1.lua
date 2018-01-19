--[[
	测试 gm_intf 相关表轮询业务
	1. 查看缓存是否正确执行
	2. 是否存在重复订单提交的问题，重复确认的订单是否正确处理
]]

local http=require "resty.http"
local dbMgr = require 'util.db_access'

local cjson   = require "cjson"
local tb    = require "resty.iresty_test"

local test = tb.new({unit_name="gm_intf_example"})

local random = math.random
local host_port  = "http://127.0.0.1:18081"

--设置一个自增的id
ngx.shared.dogs:set("oid",os.time())


function tb:init(  )
    self:log("init complete")
end

--这里的编号代表测试顺序吗？
function tb:test_00001()

	--随机流程
	local rn = random(1,10)

	self:log("插入订单")
	self:addOrders()

end

--这里的编号代表测试顺序吗？,批量使用
function tb:atest_00002()

	--随机流程
	local rn = random(1,10)

	if rn >5 then
		self:log("插入订单")
		self:addOrders()
	else
		self:log("处理订单")
		self:to_confirm()
	end

end

--查询并处理订单
function tb:to_confirm()
	local svr_count  =  random(1,10)


	local svr_names = {}
	 --随机拿一组游戏服名称
	 local svr_name
	for i=1,svr_count do
		svr_name = "360_"..random(1,10)
		table.insert(svr_names,svr_name)
	end

	svr_name = table.concat(svr_names,";")

	local body =  ngx.encode_args({ server_names = svr_name})
	local httpc =http.new();
	httpc.timeout =2000;
	local res, err = httpc:request_uri(host_port.."/gm_intf/get", {
				method = "POST",
				ssl_verify=false,
				scheme="http",
				body = body
			})


	if 200 == res.status then
		self:log("/gm_intf/get -result:", res.body)

		--解析数据
		self:confirm(res.body,svr_name)
    else
		self:log("/gm_intf/get -error:"..res.status.."  data:"..svr_name)
	end
end


--不定时插入订单
function tb:addOrders()

	local db = dbMgr.getDBObj('gm_intf')

	--要插入数据的表
	local  tb = {
		"gm_recharge","gm_notice","gm_gag","gm_level","gm_gift_packs"
		--["gm_rightfloat"],
		--["gm_kicking"],["gm_lock_ip"],["gm_lock_account"]
	}

	--每次随机插入 100 条数据
	for i=1,100 do
		local oid  = ngx.shared.dogs:incr("oid", 1)	--获取自增id


		local tb_name = tb[random(1,#tb)]		--随机拿一个张表
		local svr_name = "360_"..random(1,10) 	--随机拿一个游戏服名称

		local rand_1 = random(1,10000)	--设置一个随机数
		local rand_2 = random(0,4)	--设置一个随机数
		local rand_3 = random(1,10000)	--设置一个随机数

		local time  = os.time()

		local tbl = db[tb_name]

		if tb_name  == "gm_recharge" then

			tbl:insert({server_name = svr_name, _id = string.format("%s",oid), account = svr_name.."_"..rand_1, i_type= rand_2, i_amount = rand_1, u_adddata = time, i_status = 0})

		elseif tb_name  == "gm_notice" then

			tbl:insert({server_name = svr_name, id = oid, i_status = 0, u_start_time = time, u_end_time = time +3000, i_interval = 10, content = "test" })

		elseif tb_name  == "gm_gag" then

			tbl:insert({server_name = svr_name, id = oid, i_status = 0, guid = svr_name.."_"..rand_1 , u_end_time = time +3000, content = "test" })

		elseif tb_name  == "gm_level" then

			tbl:insert({server_name = svr_name, id = oid, i_status = 0, account = svr_name.."_"..rand_1, i_gm_level = rand_2})

		elseif tb_name  == "gm_gift_packs" then

			tbl:insert({server_name = svr_name, id = oid, i_status = 0, account = svr_name.."_"..rand_1, i_gift_type = rand_2, i_audience_type = rand_2, u_start_time = time, u_end_time = time +3000, gift_name = "test", gift_desc = "test desc", s_item_config = "1,2,3", to_id =  svr_name.."_"..rand_3})

		elseif tb_name  == "gm_rightfloat" then

		elseif tb_name  == "gm_kicking" then

		elseif tb_name  == "gm_lock_ip" then

		elseif tb_name  == "gm_lock_account" then

		else

		end

	end
end


function tb:confirm(body,server_names)
	local data  = cjson.decode(body)
	--数据结构  data[server_name] =  {tb_name = {rows1,rows2,rows3}}

	if data.ret == 1 then
		return
	end


	for svr_key,svr_data in pairs(data.data) do


		for tb_key,tb_data in pairs(svr_data) do

			local ids  = {}

			for i= 1,#tb_data do

				local tb_row = tb_data[i]

				if tb_key  == "gm_recharge" then
					table.insert(ids, tb_row._id)

				elseif tb_key  == "gm_notice" then
					table.insert(ids, tb_row.id)

				elseif tb_key  == "gm_gag" then
					table.insert(ids, tb_row.id)

				elseif tb_key  == "gm_level" then
					table.insert(ids, tb_row.account)

				elseif tb_key  == "gm_gift_packs" then
					table.insert(ids, tb_row.id)

				elseif tb_key  == "gm_rightfloat" then

				elseif tb_key  == "gm_kicking" then

				elseif tb_key  == "gm_lock_ip" then

				elseif tb_key  == "gm_lock_account" then

				else


				end

			end

			if #ids > 0 then
				local data = ngx.encode_args({server_name = svr_key, ids = table.concat(ids,","), tb = tb_key, begin_status = 0, change_status = 2 })

				-- 正常请求
				local httpc =http.new();
				httpc.timeout =2000;
				local res, err = httpc:request_uri(host_port.."/gm_intf/confirm", {
					method = "POST",
					ssl_verify=false,
					scheme="http",
					body =  data
				})

				if 200 == res.status then
					--解析数据
					local ret  = cjson.decode(res.body)
					if ret.ret == 1 then
						 self:log("failed confirm:" .. res.body.." post:"..data)
					else
						 self:log("success confirm:" .. res.body.." post:"..data)
					end

				else
					self:log("/gm_intf/confirm -error:",res.status,"  data:",data)
				end

			end
		end

	end
end

-- units test
test:run()

-- bench test(total_count, micro_count, parallels)
 --test:bench_run(10, 10,10)

