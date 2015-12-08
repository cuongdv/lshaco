local shaco = require "shaco"
local http = require "http"
local tbl = require "tbl"
local socket = require "socket"

shaco.start(function()
    local root = "../html/"
    local addr = '127.0.0.1:1234'
    print ("listen on "..addr)
    local sock = assert(socket.listen(
        addr,
        function(id)
            print ("accept", id)
            socket.start(id)
            socket.readon(id)
            local code, method, uri, head_t, body = http.read(id)
            print ('code:'..code, 'method:'..method, 'uri:'..uri)
            tbl.print(head_t, '[head]')
            print('[body]='..body)
            code = 200
            body = "1234"
            head_t = {}
            head_t["content-type"] = "text/html; charset=utf8"
            http.response(id, code, body, head_t)
            socket.shutdown(id)
        end))
end)
