local shaco = require "shaco"
local mysql = require "mysql"
local tbl = require "tbl"
local conn

shaco.start(function()
    conn = assert(mysql.connect{
        host = "127.0.0.1",
        port = 3306,
        db = "",
        user = "root",
    })
 
    local result
    result = conn:execute("use mysql")
    assert(result.err_code==nil, result.message)
    
    result = conn:execute("select * from user")
    assert(result.err_code==nil, result.message)
    print(tbl(result, 'res'))
end)
