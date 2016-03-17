local shaco = require "shaco"
local socket = require "socket"
local http = require "http"
local sslsocket = require "sslsocket"
local ssl = require "ssl"

shaco.start(function()
    --local uri = "/user/me.json"
    local uri = "/user/me.json?access_token=26538037411bf254c69c509624e328652185ade73a146df699"
    local host = "openapi.360.cn"
    local headers = {["Content-Type"]="application/json", charset="utf-8"}
    local form = nil--{access_token="26538037411bf254c69c509624e328652185ade73a146df699"}
    local port = 443
    local id = assert(socket.connect(host, port))
    print ("socket id:"..id)
    socket.readon(id)

    local ok, err = pcall(function()
        local s = ssl.connect()
        ssl.handshake(id, s)
        print ("handshake ok")
        print ("http.request ...")
        local code, body = http.request(host, uri, headers, form, 
            sslsocket.reader(id, s),
            sslsocket.sender(id, s))
        print ("[code] "..code)
        print ("[body]")
        print(body)
    end)
    print ("socket close")
    socket.close(id)
    if not ok then
        print (err)
    end
end)
