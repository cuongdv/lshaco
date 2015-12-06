local shaco = require "shaco"
local http = require "http"
local tbl = require "tbl"
local cjson = require "cjson"

shaco.start(function()
    local host = shaco.getenv("host") or "127.0.0.1:1234"
    local uri  = shaco.getenv("uri") or "/"

    local mode
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
        local code, body = http.post(host, uri, nil, {'abc'})
        print (code, body)
    end
    os.exit(1)
end)
