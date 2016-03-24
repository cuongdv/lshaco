local shaco = require "shaco"
local mysql = require "mysql"
local tbl = require "tbl"
local conn

local function mysql_exec(conn, s)
    local result, err = conn:execute(s)
    return result or {err_code=-1, message="Mysql error"}
end

shaco.start(function()
    conn = assert(mysql.connect{
        host = "127.0.0.1",
        port = 3306,
        db = "",
        user = "root",
    })
 
    local result
     
    assert(conn:use("mysql"))

    result = conn:statistics()
    print(result)

    result = conn:processinfo()
    print(tbl(result, 'res'))

    result = mysql_exec(conn, "select * from user")
    print(tbl(result, 'res'))

    result = mysql_exec(conn, "select *from user where User='lxj'")
    print(tbl(result, 'res'))

    while true do
        local ok, err = pcall(function()
            assert(conn:ping())
        end)
        if not ok then
            print (err)
        end
        shaco.sleep(1000)
        print ("sleep ...")
    end
end)
