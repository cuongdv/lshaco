local shaco = require "shaco"
local socket = require "socket"
local socketchannel = require "socketchannel"

local host = "127.0.0.1:1234"
local ip, port = string.match(host, "([^:]+):?(%d+)$")

local function test1(sc, times)
    print("[1] create", coroutine.running())
    for i=1,times do
        --print ("[1] i:"..i)
        local n = i+string.byte("0")
        if n > 255 then n = 0 end
        local s = string.char(n)
        local resp = sc:request(s.."\n", function(id)
            local r = assert(socket.read(id, "*l"))
            --print("read:", r)
            return r
        end)
        --print("[1] <----------:"..resp)
    end 
end

local function test2(sc, times)
    print("[2] create", coroutine.running())
    for i=1,times do
        --print ("[2] i:"..i)
        local n = i+string.byte("a")-1
        if n > 255 then n = 0 end
        local s = string.char(n)
        local resp = sc:request(s.."\n", function(id)
            local r = assert(socket.read(id, "*l"))
            --print("read:", r)
            return r
        end)
        --print("[2] <----------:"..resp)
    end
end

local function test3(sc, times)
    print("[3] create", coroutine.running())
    for i=1,times do
        --print ("[3] i:"..i)
        local n = i+string.byte("A")-1
        if n > 255 then n = 0 end
        local s = string.char(n)
        local resp = sc:request(s.."\n", function(id)
            local r = assert(socket.read(id, "*l"))
            --print("read:", r)
            return r
        end)
        --print("[3] <----------:"..resp)
    end
end

shaco.start(function()
    local sc = assert(socketchannel.create{
        host = ip,
        port = port,
        --auth = nil,
    })
    sc:connect()
    local times = 90000
    print ("fork 1")
    shaco.fork(test1, sc, times)
    print ("fork 2")
    shaco.fork(test2, sc, times)
    print ("fork 3")
    shaco.fork(test3, sc, times)
    print("------------------------------")
end)
