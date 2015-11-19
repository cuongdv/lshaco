local shaco = require "shaco"
local gateserver = require "gateserver"
local socket = require "socket.c"
local tbl = require "tbl"
local clients = gateserver.clients

local request_handle

local handle = {}
function handle.accept(c) end
function handle.connect(c) end
function handle.login(c) end
function handle.reject(id, reason) end
function handle.disconnect(c, forward)
    if forward then
        shaco.send(request_handle, shaco.pack(c.id, "DISCONN"))
    end
end
local function readpack(c)
    if c.head == nil then
        c.head = c.buffer:pop("*2")
        if c.head == nil then 
            return 
        end
        if c.head == 0 then
            c.head = nil
            gateserver.disconnect(c, true, "Invalid message")
            return
        end
    end
    local msg, sz = c.buffer:popbytes(c.head)
    if msg then
        c.head = nil
        return msg, sz
    end
end

local function parsepack(c, msg, sz)
    shaco.send(request_handle, shaco.pack(c.id, "REQ", msg, sz))
end

function handle.message(c)
    while true do
        local msg, sz = readpack(c)
        if not msg then break end
        if parsepack(c, msg, sz) then
            gateserver.disconnect(c, true, "Handle message error")
            c.buffer.freebytes(msg)
            return
        end
        c.buffer.freebytes(msg)
    end
end

shaco.start(function() 
    shaco.publish("cmdgate")
    request_handle = shaco.subscribe("cmds")
    assert(request_handle)

    gateserver.start(handle, {
        timeout = 1000,
        address = shaco.getenv("cmdaddress"),
        livetime = shaco.getenv("ccmdlive", 3)*1000,
        logintime = 10*1000,
        logouttime = 1*1000,
        clientmax = shaco.getenv("ccmdmax"),
    })

    shaco.dispatch("um", function(_,_, id, info) 
        local c = clients[id]
        if c then
            socket.sendpack(c.id,info)
        end
    end)
end)
