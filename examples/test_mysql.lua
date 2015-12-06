local shaco = require "shaco"
local mysql = require "mysql"
local tbl = require "tbl"
local conn

local function ping()
    shaco.trace('start exec')
    local result = conn:execute("select data from x_task where roleid=691")
    tbl.print(result)
    result = result[1]
end

shaco.start(function()
    conn = assert(mysql.connect{
        host = "192.168.1.200",
        port = 3306,
        db = "game",
        user = "game",
        passwd = "123456",
    })
   
    shaco.fork(ping)
end)
