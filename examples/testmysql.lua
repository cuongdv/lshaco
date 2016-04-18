local shaco = require "shaco"
local mysql = require "mysql"
local tbl = require "tbl"
local conn

local conf = {
    host = "127.0.0.1",
    port = 3306,
    db = "",
    user = "root",
}

shaco.start(function()
    conn = mysql.connect(conf)
    
    local result
     
    conn:use("mysql")

    result = conn:statistics()
    print(result)

    result = conn:processinfo()
    print(tbl(result, 'res'))

    result = conn:execute("select * from use")
    print(tbl(result, 'res'))

    result = conn:execute("select * from user")
    print(tbl(result, 'res'))

    result = conn:execute("select *from user where User='lxj'")
    print(tbl(result, 'res'))

    while true do
        --pcall(conn.ping, conn)
        local ok, err = pcall(conn.ping, conn)
        if not ok then
            print (err)
        end
        shaco.sleep(1000)
        print ("sleep ...")
    end
end)
