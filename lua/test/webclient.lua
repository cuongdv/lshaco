local shaco = require "shaco"
local http = require "http"
local tbl = require "tbl"
local cjson = require "cjson"

shaco.start(function()
	--local code, body = http.get("http://sdk.test4.g.uc.cn/cp/account.verifySession", "/")
 --   print (code)
  --  print(body)
	 local root = "../html/"
    local host = "sdk.test4.g.uc.cn"
	local headers = {["content-type"] = "application/json" }

	--local host = shaco.getenv("host") or "127.0.0.1:1234"
    local uri  = shaco.getenv("uri") or "/cp/account.verifySession"
	local f = io.open(root.."index.json")
    local s = f:read("*a")
	local code, body = http.post(host, uri, headers, s)
    print (code, body)
	
	
	
   --[[local code, body = http.get(host, uri)
    print(body)
    if mode == "get" then
        local code, body = http.get(host, uri)
        print(code)
        print(body)
        if body:byte(1) == 123 then -- "{"
            local t = cjson.decode(body)
            for k, v in pairs(t) do
                if type(v) == "table" then
                    tbl.print(v, k) 
                else
                    print(k..":"..v) 
                end 
            end
        end
    else
        local code, body = http.pos(host, uri, nil, {b='abc'})
        print (code, body)
    end]]
    os.exit(1)
end)
