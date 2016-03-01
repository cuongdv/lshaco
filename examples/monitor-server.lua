-- start server:    ./shaco examples/config --start "monitor-server"
-- visit:           http://127.0.0.1:8080

local shaco = require "shaco"
local http = require "http"
local socket = require "socket"
local websocket = require "websocket"
local tbl = require "tbl"

local function iostat()
    local f = io.popen("iostat", "r")
    local result = f:read("*a")
    result = string.match(result, ".*\n.*\n(.*)\n")
    if result then
        local pos = string.find(result, "[%.%d]", 1, false)
        if pos then
            result = string.sub(result, pos)
            result = string.gsub(result, "[^%.%d]+", " ")
        end
    end
    f:close()
    return result
end

local clients = {}
local client_count = 0

local function push_routine()
    while true do
        local ok, err = pcall(function()
            if client_count > 0 then
                local result = iostat()
                if result then
                    shaco.trace(result)
                    for id, c in pairs(clients) do
                        websocket.text(id, "#mon:"..result)
                    end
                end
            end
        end)
        if not ok then
            print(err)
        end
        shaco.sleep(5000)
    end
end

local function read_routine(id)
    assert(clients[id] == nil)
    clients[id] = true
    client_count = client_count + 1
    local ok, err = pcall(function()
        while true do
            local data, type = websocket.read(id)
            if not data and type=="close" then
                break
            end
            print (string.format("[data] %d:%s", id, data))
        end
    end)
    if not ok then
        print(err)
    end
    socket.close(id)
    clients[id] = nil
    client_count = client_count - 1
end

shaco.start(function()
    local root = "./examples"
    local host = shaco.getenv("host") or "0.0.0.0:8080"
    local lid = assert(socket.listen(host, function(id, addr)
        print (string.format("new connection [%d] %s", id, addr))
        socket.start(id)
        socket.readon(id)
        local code, method, uri, head_t, body, version = http.read(id)
        if code ~= 200 then
            socket.close(id)
            return
        end
        if method ~= "GET" then
            socket.close(id)
            return
        end
        if uri == "/" then -- default for main
            uri = "/monitor-client.html"
        end
        if uri == "/echo" then -- tag websocket
            websocket.handshake(id, code, method, uri, head_t, body, version)
            read_routine(id)
        elseif string.find(uri, "favicon") then
            http.response(id, 200, nil, 
                {["content-type"]="image/x-icon", connection="close"})
            socket.close(id)
        else
            local f = io.open(root..uri)
            local body = f and f:read("*a") or "not resouce"
            http.response(id, 200, body, 
                {["content-type"]="text/html; charset=utf8", connection="close"})
            socket.close(id)
        end
    end))
    shaco.trace("listen on: "..host)
    shaco.fork(push_routine)
end)
