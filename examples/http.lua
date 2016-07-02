local shaco = require "shaco"
local socket = require "socket"
local http = require "http"
local tbl = require "tbl"
local md5 = require "md5"

local function test() 
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
end

local function test_sdk()
	--local addr = CTX.sdkaddr["39"]
	--local host = CTX.sdkhost["39"]
    local addr = "sdk.sp.cc"
    local host = "sdk.sp.cc"
	local headers = {["host"]=host, ["Content-type"] = "application/x-www-form-urlencoded" }
	local uri  = "sdk.sp.cc/pay/verify"
	local uri  = "/pay/verify"
	local content = 'order_id=GCfdf2e23a43553c36cc71&app_order_id=51-20160523142445-763886&client_id='..
	'ry_android&app_name=荣耀(安卓)&gateway=6&user_id=2692152&product_id=1&product_name=product_1&'..
	'account=1&price=100&client_secret=3123e31de093b63625abac771f512f0d'
	local code, body = http.post(addr, uri, headers, content)
    print(code, body)
end

shaco.start(function()
    test_sdk()    
end)
