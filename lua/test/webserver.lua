local shaco = require "shaco"
local http = require "http"
local tbl = require "tbl"
local socket = require "socket"

shaco.start(function()
    local root = "../html/"
    local host = shaco.getenv("host") or "0.0.0.0:1234"
    local ip, port = host:match("([^:]+):?([%d]+)$")
    print (ip, port)
    local lid = assert(socket.listen(ip, port))
    print ("listen on",lid,host)
    socket.start(lid, function(id)
        print ("accept", id)
        shaco.fork(function()
            socket.start(id)
            socket.readenable(id, true)
            local code, method, uri, head_t, body = http.read(id)
            print(code, method, uri, head_t, body)
            tbl.print(head_t)
            code = 200
            body = "1234"
            local f = io.open(root.."index.html")
            local s = f:read("*a")
            body = s
            head_t = {}
            head_t["content-type"] = "text/html; charset=utf8"
            http.response(id, code, body, head_t)
            socket.shutdown(id)
        end)  
    end)
end)
