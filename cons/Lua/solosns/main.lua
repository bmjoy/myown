--sns服务器主控脚本

--程序状态
local WAPS_UNKNOWN = 0	--未知
local WAPS_STARTING = 1	--正在启动
local WAPS_READY = 2	--就绪（但是未开放服务）
local WAPS_OPENING = 3	--正在开放服务
local WAPS_OPENED = 4	--已开放服务
local WAPS_CLOSING = 5	--正在关闭
local WAPS_CLOSED = 6	--已关闭服务
local WAPS_QUITING = 7	--正在退出

--入口函数
function main(sns)
	nx_set_value("sns", sns)
	
	--快速日志系统
	sns.UseQuickLog = true
	--应用进程记录
	sns.UseAppRecord = true
	
	--屏幕输出字符颜色
	sns:SetConsoleColor("White")
	
	--读取程序配置
	local ini = nx_create("IniDocument")
	
	--配置文件名
	--ini.FileName = "game_sns.ini"
	ini.FileName = nx_main_config()
	
	--加载配置
	if not ini:LoadFromFile() then
		nx_msgbox("can't read config file!")
		nx_destroy(ini)
		return 0
	end
	
	--游戏分区编号
	local district_id = ini:ReadInteger("Main", "DistrictID", 1)
	--服务器编号
	local server_id = ini:ReadInteger("Main", "ServerID", 1)
	--组内存储编号
	local sns_id = ini:ReadInteger("Main", "StoreID", 0)
	--sns逻辑DLL文件
	--local logic_dll = ini:ReadString("Main", "PublicLogicDll", "")
	--保存公共数据的间隔时间
	local save_minutes = ini:ReadInteger("Main", "SaveMinutes", 20)
		--使用MYSQL数据库
	local use_mysql = nx_boolean(ini:ReadString("Main", "UseMysql", "false"))
	
		--创建数据库系统
	local db_system
	
	if use_mysql then
		db_system = nx_create("MysqlDBSystem")
	else
		db_system = nx_create("SqlDBSystem")
	end
	
		sns.DBSystem = db_system
		
		--sns
	local use_sns = nx_boolean(ini:ReadString("Main", "UseSns", "false"))
	local sns_server_count = ini:ReadInteger("Main", "SnsServerCount", 0)
	
	--内网地址
	local inner_addr = "127.0.0.1"
	--local inner_port = 0
	
	inner_addr = ini:ReadString("Inner", "Addr", inner_addr)
	--inner_port = ini:ReadInteger("Inner", "Port", inner_port)
	
	--广播地址
	local broad_addr = "127.255.255.255"
	local broad_port = 15000
	
	broad_addr = ini:ReadString("Broadcast", "Addr", broad_addr)
	broad_port = ini:ReadInteger("Broadcast", "Port", broad_port)
	
	--维护连接地址
	local echo_addr = "127.0.0.1"
	local echo_port = 15025
	
	echo_addr = ini:ReadString("Echo", "Addr", echo_addr)
	echo_port = ini:ReadInteger("Echo", "Port", echo_port)
	
        --WSASend函数发送数组的个数(最大16个,默认是8)
	local wsasend_arrays = ini:ReadInteger("Main", "WSASendArrays", 8)
	--WSASend函数发送缓存大小(最大64M,默认是1M)
	local wsasend_buflen = ini:ReadInteger("Main", "WSASendBufLen", 1048576)		
	local sns_base = ini:ReadString("Sns", "ConnectString", "")
	
    --Sns逻辑模块
    local sns_logic_loader = nx_create("LogicLoader")
    
    local sns_logic_path = ini:ReadString("SnsLogic", "Path", "")
    local sns_modules = ini:ReadInteger("SnsLogic", "Modules", 0)
    
    if sns_logic_path ~= "" and sns_modules == 0 then
        local fs = nx_create("FileSearch")
        
        fs:SearchFile(nx_work_path() .. sns_logic_path .. "\\", "*.dll")
        
        local dll_table = fs:GetFileList()
        
        for i = 1, table.getn(dll_table) do
            if sns_logic_loader:Load(nx_work_path() .. sns_logic_path .. "\\", dll_table[i]) then
                sns:WriteLine("load loigc module " .. dll_table[i])
            else
                sns:WriteLine("load loigc module " .. dll_table[i] .. " failed")
            end
        end
        
        nx_destroy(fs)
    else
        for i = 0, sns_modules do
            local dll_name = ini:ReadString("SnsLogic", "Module" .. nx_string(i), "")
            
            if dll_name ~= "" then
                if sns_logic_loader:Load(nx_work_path() .. sns_logic_path, dll_name) then
                    sns:WriteLine("load loigc module " .. dll_name)
                else
                    sns:WriteLine("load loigc module " .. dll_name .. " failed")
                end
            end
        end
    end
    
	nx_destroy(ini)
	
	--绑定脚本
	nx_bind_script(sns, "main", "echo_init")
	
	sns.AppName = "sns_" .. nx_string(server_id) .. "_" .. nx_string(sns_id)
	sns.DistrictId = district_id
	sns.ServerId = server_id
	sns.SnsId = sns_id
	sns.SaveMinutes = save_minutes
	sns.LogicLoader = sns_logic_loader
	sns.InnerAddr = inner_addr
	sns.InnerPort = inner_port
	sns.OuterAddr = outer_addr
	sns.OuterPort = outer_port
	sns.BroadAddr = broad_addr
	sns.BroadPort = broad_port
	sns.EchoAddr = echo_addr
	sns.EchoPort = echo_port
  sns.WSASendArrays = wsasend_arrays
	sns.WSASendBufLen = wsasend_buflen
	--sns.DBSystem = db_system
	sns.SnsBase = sns_base
	sns.SnsServerCount = sns_server_count
	sns.SnsPerformance = true
	sns.SnsOvertimeValue = 100
  
	--保证启动日志服务
	sns.LogLauncher = "game_log game_log.ini daemon"

	--启动sns服务
	sns:Start()
	
	--实际使用的内网侦听端口
	--inner_port = sns.InnerPort
	
	--显示应用程序名
	sns:WriteLine("app name " .. sns.AppName)
	--显示通讯地址和端口
	sns:WriteLine("echo socket " .. echo_addr .. ":" .. nx_string(echo_port))
	--sns:WriteLine("inner socket " .. inner_addr .. ":" .. nx_string(inner_port))
	sns:WriteLine("broadcast socket " .. broad_addr .. ":" .. nx_string(broad_port))
	--启动完成
	sns:WriteLine("game sns server " .. nx_string(server_id) .. " sns "
		.. nx_string(sns_id) .. " started")
	
	--设置进程开启状态
	sns:SetAppState(WAPS_OPENED);
	
	return 1
end

--关闭
function close()
	local sns = nx_value("sns")
	
	--关闭公共数据服务
	sns:WriteLine("sns server shutdown...")
	sns:Stop()
	
	--结束程序
	nx_quit()
	
	return true
end

--维护连接脚本

--初始化
function echo_init(self)
	nx_callback(self, "on_open", "echo_open")
	nx_callback(self, "on_close", "echo_close")
	nx_callback(self, "on_input", "echo_input")
	
	nx_callback(self, "on_input_getp", "echo_input_getp")
	nx_callback(self, "on_input_setp", "echo_input_setp")
	nx_callback(self, "on_input_getc", "echo_input_getc")
	nx_callback(self, "on_input_setc", "echo_input_setc")
	nx_callback(self, "on_input_method", "echo_input_method")
	nx_callback(self, "on_input_listp", "echo_input_listp")
	nx_callback(self, "on_input_listc", "echo_input_listc")
	nx_callback(self, "on_input_listm", "echo_input_listm")
	nx_callback(self, "on_input_listg", "echo_input_listg")
	nx_callback(self, "on_input_function", "echo_input_function")
	nx_callback(self, "on_input_debugger", "echo_input_debugger")
	
	return 1
end

--维护连接打开
function echo_open(self, addr, port)
	self:WriteLine("echo client " .. nx_string(addr) 
		.. ":" .. nx_string(port) .. " connected")
	self:SendEchoLine("welcome sns server " .. nx_string(self.ServerId) .. "\r")
	return 1
end

--维护连接关闭
function echo_close(self, addr, port)
	self:WriteLine("echo client " .. nx_string(addr) 
		.. ":" .. nx_string(port) .. " closed")
	return 1
end

--发送回应信息
function echo_response(self, info)
	self:SendEchoLine(">" .. info .. "\r")
	self:WriteLine(info)
	return true
end

--处理维护输入命令
function echo_input(self, command)
	if command == "quit" then
		--退出程序
		echo_response(self, "server will shutdown...")
		close()
	elseif command == "end" then
		--关闭连接
		self:CloseEcho()
	else
		echo_response(self, "undefined command: " .. command)
	end
	
	return 1
end

--查找实体
function get_entity(entity_name)
	local id = nx_value(entity_name)
	
	if id ~= nil then
		return id
	end
	
	id = nx_lookup(entity_name)
	
	if not nx_is_null(id) then
		return id
	end
	
	id = nx_object(entity_name)
	
	if nx_is_valid(id) then
		return id
	end
	
	return nil	
end

--转换到合适的类型
function get_new_value(old_v, value)
	local type = nx_type(old_v)
	
	if type == "boolean" then
		return nx_boolean(value)
	elseif type == "number" then
		return nx_number(value)
	elseif type == "string" then
		return nx_string(value)
	elseif type == "widestr" then
		return nx_widestr(value)
	elseif type == "int" then
		return nx_int(value)
	elseif type == "int64" then
		return nx_int64(value)
	elseif type == "float" then
		return nx_float(value)
	elseif type == "double" then
		return nx_double(value)
	elseif type == "object" then
		return nx_object(value)
	end
		
	return nil	
end

--查询实体内部属性
function echo_input_getp(self, entity, prop)
	if entity == nil or prop == nil then
		return 0
	end
	
	local obj = get_entity(nx_string(entity))
	
	if obj == nil then
		return 0
	end
	
	local value = nx_property(obj, nx_string(prop))
	
	echo_response(self, "entity " .. nx_name(obj) .. " property " 
		.. nx_string(prop) .. " value is " .. nx_string(value))
	
	return 1
end

--设置实体内部属性
function echo_input_setp(self, entity, prop, value)
	if entity == nil or prop == nil then
		return 0
	end
	
	local obj = get_entity(nx_string(entity))
	
	if obj == nil then
		return 0
	end
	
	local old_v = nx_property(obj, nx_string(prop))
	
	local new_v = get_new_value(old_v, value)
	
	if not nx_set_property(obj, nx_string(prop), new_v) then
		echo_response(self, "set property failed")
		return 0
	end
	
	new_v = nx_property(obj, nx_string(prop))
	
	echo_response(self, "set entity " .. nx_name(obj) .. " property " 
		.. nx_string(prop) .. " value " .. nx_string(new_v))
	
	return 1
end

--查询实体自定义属性
function echo_input_getc(self, entity, prop)
	if entity == nil or prop == nil then
		return 0
	end
	
	local obj = get_entity(nx_string(entity))
	
	if obj == nil then
		return 0
	end
	
	local value = nx_custom(obj, nx_string(prop))
	
	echo_response(self, "entity " .. nx_name(obj) .. " custom " 
		.. nx_string(prop) .. " value is " .. nx_string(value))
	
	return 1
end

--设置实体自定义属性
function echo_input_setc(self, entity, prop, value)
	if entity == nil or prop == nil then
		return 0
	end
	
	local obj = get_entity(nx_string(entity))
	
	if obj == nil then
		return 0
	end
	
	local old_v = nx_custom(obj, nx_string(prop))
	
	local new_v = get_new_value(old_v, value)
	
	if not nx_set_custom(obj, nx_string(prop), new_v) then
		echo_response(self, "set custom failed")
		return 0
	end
	
	new_v = nx_custom(obj, nx_string(prop))
	
	echo_response(self, "set entity " .. nx_name(obj) .. " custom " 
		.. nx_string(prop) .. " value " .. nx_string(new_v))
	
	return 1
end

--执行实体方法
function echo_input_method(self, entity, method, ...)
	if entity == nil or method == nil then
		return 0
	end
	
	local obj = get_entity(nx_string(entity))
	
	if obj == nil then
		return 0
	end
	
	local res = nx_method(obj, nx_string(method), unpack(arg))
	
	if type(res) == "table" then
		echo_response(self, "run entity " .. nx_name(obj) .. " method " 
			.. nx_string(method) .. " return table")
		
		for i = 1, table.getn(res) do
			echo_response(self, "table value " .. nx_string(i) .. ": " .. nx_string(res[i]))
		end
	else
		echo_response(self, "run entity " .. nx_name(obj) .. " method " 
			.. nx_string(method) .. " return " .. nx_string(res))
	end
	
	return 1
end

--列出实体的所有内部属性
function echo_input_listp(self, entity)
	if entity == nil then
		return 0
	end
	
	local obj = get_entity(nx_string(entity))
	
	if obj == nil then
		return 0
	end
	
	local prop_table = nx_property_list(obj)
	
	local num = table.getn(prop_table)
	
	echo_response(self, "entity " .. nx_name(obj) .. " property number is " .. nx_string(num))
	
	for i = 1, num do
		echo_response(self, nx_string(prop_table[i]))
	end
	
	return 1
end

--列出实体的所有自定义属性
function echo_input_listc(self, entity)
	if entity == nil then
		return 0
	end
	
	local obj = get_entity(nx_string(entity))
	
	if obj == nil then
		return 0
	end
	
	local prop_table = nx_custom_list(obj)
	
	local num = table.getn(prop_table)
	
	echo_response(self, "entity " .. nx_name(obj) .. " custom number is " .. nx_string(num))
	
	for i = 1, num do
		echo_response(self, nx_string(prop_table[i]))
	end
	
	return 1
end

--列出实体的所有方法
function echo_input_listm(self, entity)
	if entity == nil then
		return 0
	end
	
	local obj = get_entity(nx_string(entity))
	
	if obj == nil then
		return 0
	end
	
	local prop_table = nx_method_list(obj)
	
	local num = table.getn(prop_table)
	
	echo_response(self, "entity " .. nx_name(obj) .. " method number is " .. nx_string(num))
	
	for i = 1, num do
		echo_response(self, nx_string(prop_table[i]))
	end
	
	return 1
end

--列出所有全局变量
function echo_input_listg(self)
	local global_table = nx_value_list()
	
	local num = table.getn(global_table)
	
	echo_response(self, "global number is " .. nx_string(num))
	
	for i = 1, num do
		local name = global_table[i]
		local value = nx_value(name)
		
		echo_response(self, nx_string(name) .. "[" .. nx_type(value) .. "]: " .. nx_string(value))
	end
	
	return 1
end

--执行脚本扩展函数
function echo_input_function(self, func, ...)
	if func == nil or func == "" then
		return 0
	end
	
	local res = nx_function(func, unpack(arg))
	
	if type(res) == "table" then
		echo_response(self, "run function " .. nx_string(func) .. " return table")
		
		for i = 1, table.getn(res) do
			echo_response(self, "result" .. nx_string(i) .. ": " .. nx_string(res[i]))
		end
	else
		echo_response(self, "run function " .. nx_string(func) .. " return " .. nx_string(res))
	end
	
	return 1
end


--调试函数
function echo_input_debugger(self, entity, method, ...)
	if entity == nil or entity == "" or method == nil or method == "" then
		return 0
	end
	
	local obj = get_entity(nx_string(entity))
	
	if obj == nil then
		return 0
	end
	
	local res = nx_method(obj, nx_string(method), unpack(arg))
	
	if type(res) == "table" then
		--echo_response(self, "run entity " .. nx_string(entity) .. " method " .. nx_string(method) .. " return table")
			self:SendEchoLine(">" .. "run entity " .. nx_string(entity) .. " method " .. nx_string(method) .. " return table" .. "\r")
		
		for i = 1, table.getn(res) do
			--echo_response(self, "result" .. nx_string(i) .. ": " .. nx_string(res[i]))
				self:SendEchoLine(">" .. "result" .. nx_string(i) .. ": " .. nx_string(res[i]) .. "\r")
		end
	else
		--echo_response(self, "run entity " .. nx_string(entity) .. " method " .. nx_string(method) .. " return " .. nx_string(res))
		self:SendEchoLine(">" .. "run entity " .. nx_string(entity) .. " method " .. nx_string(method) .. " return " .. nx_string(res) .. "\r")
	end
	
	return 1
end