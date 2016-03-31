local shaco = require "shaco"
local socket = require "socket"
local http = require "http"
local tbl = require "tbl"
local md5 = require "md5"

shaco.start(function()
    print ('get ...')
    local code, body = http.get("www.baidu.com", "/", {a=1, b=2})
    print (code)
    print(body)

    local sid = "1234"
    local sign = "sid="..sid.."0ee95ce35197bb31e221574088275611"
	
    local sign = md5.sumhexa(sign)
    --local host = "sdk.g.uc.cn"
    local host = "221.228.102.132"
    local headers = {["host"]="sdk.g.uc.cn", ["content-type"]="application/json" }
    local uri  = shaco.getenv("uri") or "/cp/account.verifySession"
    local time = shaco.now()
    local value = '{"id":'..time..',"game":{"gameId":666956},"data":{"sid":"'..sid..'"},"sign":"'..sign..'"}'
    local code, body = http.post(host, uri, headers, value)
    print (code, body)

end)
