local shaco = require "shaco"
local http = require "http"
local tbl = require "tbl"
local socket = require "socket"
local websocket = require "websocket"
local crypt = require "crypt.c"

print(assert(crypt.base64encode(crypt.sha1("dGhlIHNhbXBsZSBub25jZQ==".."258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))=="s3pPLMBiTxaQ9kYGzzhZRbK+xOo="))
shaco.start(function()
    local root = "../html"
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
            print ("start:================", id)
            local code, method, uri, head_t, body, version = http.read(id)
            print(id, code, method, uri, head_t, body, version)
            tbl.print(head_t)
            code = 200
            body = "1234"
            if uri == '/' then
                uri = "/index_ws.html"
            end
            if uri == "/test.js" then
                websocket.handshake(id, code, method, uri, head_t, body, version)
                print( assert(websocket.read(id)))
                print( assert(websocket.read(id)))
                local s = "1234567890"
                s = string.rep(s, 20)
                websocket.send(id, s) 
                websocket.send(id, "1")
                websocket.send(id, tostring(os.time()))
                while true do
                    websocket.send(id, os.date())
                    shaco.sleep(1000)
                end
                websocket.close(id, 1789, "close by server")
                --websocket.write(id, "close")
            else
                local f = io.open(root..uri)
                local body = f and f:read("*a") or "not resouce"
                head_t = {}
                head_t["content-type"] = "text/html; charset=utf8"
                http.response(id, code, body, head_t)
                socket.shutdown(id)
            end
        end)  
    end)
end)
