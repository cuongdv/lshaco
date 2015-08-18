local shaco = require "shaco"
local socket = require "socket"
local util = require "util.c"
local pack_size = tonumber(shaco.getenv("pack_size")) or 1024

print ("pack_size:"..pack_size)
local MSG = string.rep("1",pack_size).."\n"

local ip, port = shaco.getstr("gateaddress"):match("([^:]+):?(%d*)$")
local client_count = tonumber(shaco.getenv("client_count")) or 1000
local pack_count = tonumber(shaco.getenv("pack_count")) or 1000
local stat = 0
local start_time
local connect_ok = 0
local clients = {}

local function client(uid)
    local id = assert(socket.connect(ip,port))
    connect_ok = connect_ok+1
    shaco.trace("connect ok = "..connect_ok.." id=".. id)
    coroutine.yield()

    shaco.trace("begin read:"..id)
    socket.readenable(id, true)
    while true do
        --socket.send(id, MSG)
        --socket.read(id, "*l")
        
        local p, sz = shaco.pack(1, "1234567890")
        local s = util.bytes2str(p, sz)
        util.freebytes(p)
        assert(socket.send(id, string.pack("<s2", s)))
        local h = assert(socket.read(id, "*2"))
        local s = assert(socket.read(id, h))
        local p, sz = util.str2bytes(s)
        local id, id2 = shaco.unpack(p, sz) 
        assert(id==1)
        assert(id2=="1234567890")
        stat = stat+1
        if stat == pack_count then
            stat = 0
            local now = shaco.now()
            util.printr(string.format("client_count=%d,pack_count=%d, pack_size=%d, use time=%d, pqs=%.02f", 
                client_count, pack_count, pack_size, now-start_time, pack_count/(now-start_time)*1000))
            start_time = now
        end
    end

end

local function fork(f,...)
    local m = function (...)
        assert(xpcall(f, debug.traceback,...))
    end
    local co = coroutine.create(m)
    assert(coroutine.resume(co, ...))
    return co
end

local function wakeup(co, ...)
    assert(coroutine.resume(co, ...))
end

local tick = 0
local connected = false
shaco.start(function()
    shaco.timeout(1000, function()
        if connect_ok == client_count then 
            shaco.trace('all connect ok:'..client_count)
            connected = true
            connect_ok = 0
        end
        if connected then
            connected = false
            for _, co in ipairs(clients) do
                wakeup(co)
            end
        end
    end)
    start_time = shaco.now()
    for i=1, client_count do
        local co = fork(client,i)
        table.insert(clients,co)
    end
end)
