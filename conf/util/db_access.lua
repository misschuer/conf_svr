local dbMgr = {}

require 'util.functions'
local mongoc_wrap   = require 'mongoc.mongo'

--转换2.X驱动的数据库字符串为3.0驱动的字符串
function exchangeDBString( connection_string )
    local connection_string_table = string.split(connection_string, ";")--lua_split_data(connection_string)
    local ip = connection_string_table[1]
    local port = connection_string_table[2]
    local user = connection_string_table[3]
    local pwd = connection_string_table[4]
    local new_str = "mongodb://"
    if user ~= '' and pwd ~= '' then
        new_str = new_str..user..":"..pwd.."@"
    end
    new_str = new_str..ip
    if port ~= '' then
         new_str = new_str..":"..port
    end
    new_str=new_str.."/admin"
    return new_str
end

--打开数据库连接
function createMongoDB( connection_string)      
	local new_auth_str = exchangeDBString( connection_string )
    --  mongodb_string = '127.0.0.1;27017;dev;asdf;char',
    -- local connection_string_table = string.split(connection_string, ";")--lua_split_data(connection_string)
    -- local ip = connection_string_table[1]
    -- local port = connection_string_table[2]
    -- local user = connection_string_table[3]
    -- local pwd = connection_string_table[4]

    -- local db2 = require('mongo').client {host = ip, port = port}
	
	local db2 = mongoc_wrap.new(new_auth_str)
	if not db2 then
        --error( 'failed to parse SCRAM uri\n')
        print("db open fail~~~~~~~~~~~~~~~",new_auth_str)
        return nil
    end
    --身份验证
    --如果数据库名为空字符串则转成nil 
    -- if user and user ~= '' and pwd and pwd ~= '' and not db2:authenticate('admin' , user, pwd) then
        -- --self.conf.err_callback(4,'db:Open [%s] faird',connection_string)
        -- print("db open fail~~~~~~~~~~~~~~~",connection_string)
        -- db2:disconnect()
        -- return nil
    -- end
    return db2
end

function dbMgr.clear()
	if(dbMgr.db2)then
        --dbMgr.db2.client.mongoc_cleanup()
        dbMgr.db2 = nil
	end
	dbMgr = {}
end

--获得数据库连接
function dbMgr.getDBObj(db_name)
    if not dbMgr[db_name] then
        dbMgr.db2 = createMongoDB( conf.db_string)
        if(not dbMgr.db2)then
            return nil
        end
        dbMgr[db_name] = dbMgr.db2:getDB(db_name)
    end
    return dbMgr[db_name]
end

return dbMgr
