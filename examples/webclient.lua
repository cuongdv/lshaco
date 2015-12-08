local shaco = require "shaco"
local http = require "http"
local tbl = require "tbl"

local mode = ... or 'get'

shaco.start(function()
    local host = shaco.getenv("host") or "127.0.0.1:1234"
    local uri  = shaco.getenv("uri") or "/"

    print ('mode:'..mode)
    if mode == "get" then
        local code, body = http.get(host, uri)
        print ('code:'..code)
        print ('[body]='..body)
    else
        local code, body = http.post(host, uri, nil, {'abc'})
        print ('code:'..code)
        print ('[body]='..body)
    end
end)
