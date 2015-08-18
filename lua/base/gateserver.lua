local shaco = require "shaco"
local socket = require "socket.c"
local socketbuffer = require "socketbuffer.c"
local string = string
local ipairs = ipairs
local pairs = pairs
local assert = assert

local S_FREE        = 0
local S_CONNECTED   = 1
local S_LOGINED     = 2
local S_LOGOUTED    = 3

local gateserver = {}

local clients = {}
local handle
local handle_shutdown

local clientcount = 0
local clientmax
local slimit
local rlimit
local livetime
local logintime 
local logouttime

local function client_new(id)
    return {
        id = id,
        status = S_CONNECTED,
        active_time = shaco.now(),
        buffer = socketbuffer.new(),
        head = nil,
    }
end

local function accept(id)
    assert(id ~= -1)
    if handle_shutdown then
        handle.reject(id, 1)
        socket.close(id, false)
        shaco.trace("client "..id.." reject: handle shutdown")
        return
    end
    if clientcount >= clientmax then
        handle.reject(id, 2)
        socket.close(id, false)
        shaco.trace("client "..id.." reject: gate full")
        return
    end
    assert(clients[id] == nil)
    local c = client_new(id)
    clients[id] = c
    clientcount = clientcount+1
    socket.limit(id, slimit, rlimit)
    socket.readenable(id, true)
    handle.connect(c)
    shaco.trace("client "..id.." accepted")
    return c
end

local function login(c)
    assert(c.status == S_CONNECTED)
    c.status = S_LOGINED
    c.active_time = shaco.now()
    handle.login(c)
    shaco.trace("client "..c.id.." logined")
end

local function disconnect(c, force, reason)
    if (not c) or (c.status == S_FREE) then return end
    local closed = socket.close(c.id, force)
    if closed then
        shaco.trace("Client "..c.id.." disconnect: "..reason)
        handle.disconnect(c, c.status == S_LOGINED, reason)
        c.status = S_FREE
        clients[c.id] = nil
        clientcount = clientcount - 1
    elseif c.status ~= S_LOGOUTED then
        shaco.trace("Client "..c.id.." logout")
        c.status = S_LOGOUTED
        c.active_time = shaco.now()
    end 
end

local SOCKET = {}

-- LS_EREAD
SOCKET[0] = function(id)
    local c = clients[id] 
    local data, n = socket.read(id)
    if data then
        c.buffer:push(data,n)
        handle.message(c)
    elseif n then
        disconnect(c, true, socket.error(n))
    end
end

-- LS_EACCEPT
SOCKET[1] = function(id)
    local c = accept(id)
    if c then
        login(c)
    end
end

-- LS_ESOCKERR
SOCKET[4] = function(id, err)
    local c = clients[id]
    if c then 
        disconnect(c, true, socket.error(err))
    end
end

shaco.register_protocol {
    id = shaco.PTYPE_SOCKET,
    name = "socket",
    unpack = socket.unpack,
    dispatch = function(_,_,type, ...)
        local f = SOCKET[type]
        if f then f(...) end
    end,
}

local function timeout()
    local now = shaco.now()
    for _, c in pairs(clients) do
        if c.status == S_CONNECTED then
            if now - c.active_time > logintime then
                disconnect(c, true, "timeout login")
            end
        elseif c.status == S_LOGINED then
            if livetime > 0 and
               livetime < now - c.active_time then
                disconnect(c, true, "timeout heartbeat")
            end
        elseif c.status == S_LOGOUTED then
            if now - c.active_time > logouttime then
                disconnect(c, true, "timeout logout")
            end
        end
    end
end

function gateserver.start(h, cfg)
    handle = h
    clientmax = cfg.clientmax or 1
    livetime = cfg.livetime or 3000
    logintime = cfg.logintime or 10000
    logouttime = cfg.logouttime or 3000
    slimit = cfg.slimit or 0
    rlimit = cfg.rlimit or 0
    shaco.info(string.format("listen on %s", cfg.address))
    local ip, port = cfg.address:match("([^:]+):?(%d*)$")
    assert(socket.listen(ip, port))
    shaco.timeout(1000, timeout)
end

gateserver.disconnect = disconnect
gateserver.clients = clients
gateserver.send = function(c, data, ...)
    local err = socket.send(c.id, data, ...)
    if err then
        disconnect(c, true, socket.error(err))
    else return true end
end
return gateserver
