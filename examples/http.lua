local shaco = require "shaco"
local socket = require "socket"
local http = require "http"
local tbl = require "tbl"

shaco.start(function()
    print ('get ...')
    local code, body = http.get("www.baidu.com", "/", {a=1, b=2})
    print (code)
    print(body)
end)
