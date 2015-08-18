local shaco = require "shaco"
local sfmt = string.format
local floor = math.floor
local mysql = require "mysql"
local REQ = require "req"
local snapshot = require "snapshot"
local tbl = require "tbl"
local CTX = require "ctx"
REQ.__REG {
    "h_dblog"
}

local conn
local update_flag = false
local refresh_time = 0

local function create_log()
	local t = {
		"`logid` int(11) NOT NULL AUTO_INCREMENT,`roleid` int(11) NOT NULL,`coin` int(11)  NOT NULL,`gold` int(11) NOT NULL,`create_time` datetime  NOT NULL",
		"`logid` int(11) NOT NULL AUTO_INCREMENT,`roleid` int(11) NOT NULL,`role_level` int(11)  NOT NULL,`create_time` datetime  NOT NULL",
		"`logid` int(11) NOT NULL AUTO_INCREMENT,`roleid` int(11) NOT NULL,`create_time` datetime  NOT NULL",
		"`logid` int(11) NOT NULL AUTO_INCREMENT,`roleid` int(11) NOT NULL,`buy_type` varchar(45)  NOT NULL,`cards` varchar(125) NOT NULL,`create_time` datetime  NOT NULL",
		"`logid` int(11) NOT NULL AUTO_INCREMENT,`roleid` int(11) NOT NULL,`itemid` int(11)  NOT NULL,`itemcnt` int(11) NOT NULL,`create_time` datetime  NOT NULL",
		"`logid` int(11) NOT NULL AUTO_INCREMENT,`roleid` int(11) NOT NULL,`login_time` datetime  NOT NULL,`logout_time` datetime NOT NULL",
		"`logid` int(11) NOT NULL AUTO_INCREMENT,`roleid` int(11) NOT NULL,`ectypeid` int(11)  NOT NULL,`clubid` int(11) NOT NULL,"..
			"`pos_level_breakthrough_guarantee` varchar(64) NOT NULL,`battle_value` int(11) NOT NULL,`opponent_battle` int(11) NOT NULL,`robot_id` int(11) NOT NULL,`cur__time` datetime NOT NULL"
	}
	local tb_name = {os.date("x_log_money_%Y%m%d", shaco.now()//1000),os.date("x_log_level_%Y%m%d",shaco.now()//1000),os.date("x_log_create_%Y%m%d", shaco.now()//1000),os.date("x_log_card_%Y%m%d", shaco.now()//1000),os.date("x_log_item_%Y%m%d", shaco.now()//1000),
						os.date("x_log_in_out_%Y%m%d", shaco.now()//1000),os.date("x_log_role_cheat_%Y%m%d",shaco.now()//1000)}
	local indx = 1
	for k, u in pairs(t) do
		local tb = {}
		table.insert(tb,string.format("%s",u))
		local s =table.concat(tb,",")
		local sql = string.format("CREATE TABLE IF NOT EXISTS `%s`( %s ,PRIMARY KEY (`logid`))ENGINE=MyISAM AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;",tb_name[indx],s)
		local result = conn:execute(sql)
		if result.err_code then
			shaco.warning(sfmt("role %s savefail: %s", tb_name[indx], result.message))
		else
			shaco.trace(sfmt("role v.name = = %s save ok",tb_name[indx]))
		end
		indx = indx + 1
	end
	refresh_time = shaco.now()
end

local function ping()
    while true do
        conn:ping()
        --shaco.info("ping")
        shaco.sleep(1800*1000)
    end
end


shaco.start(function()
    shaco.publish("dblog")
    shaco.subscribe("game")
   
    conn = assert(mysql.connect{
        host = shaco.getstr("logdb_host"), 
        port = shaco.getstr("logdb_port"),
        db = shaco.getstr("logdb_name"), 
        user = shaco.getstr("logdb_user"), 
        passwd = shaco.getstr("logdb_passwd"),
    })

    create_log()

    shaco.timeout(1000, function()
        local now = shaco.now()
		local now_day = floor(now/86400)
		local last_day = floor(refresh_time/86400)
		if now_day ~= last_day then
			refresh_time = now
			shaco.fork(create_log)
		end
    end)
    shaco.dispatch("um", function(session, source, name, v)
        local h = REQ[name]
        if h then
            h(conn, source, session, v)
        else
            shaco.warning(sfmt("db recv invalid msg %s", name))
        end
    end)

    shaco.fork(ping)
end)
