local shaco = require "shaco"
local gateserver = require "gateserver"
local socket = require "socket.c"

local server = {}

function server.connect(id, addr)
    shaco.trace('connect '..id..' '..addr)
    gateserver.openclient(id)
end

function server.disconnect(id, err)
    shaco.trace('disconnect '..id)
end

function server.message(id, data)
    --shaco.trace('message '..id, data)
    socket.send(id, string.pack('>s2', '+PONG\r\n'))
    --socket.send(id, string.pack('>s2', data))
end

function server.command(cmd, ...)
end

gateserver.start(server)
