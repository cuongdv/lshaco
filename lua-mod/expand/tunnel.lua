local shaco = require "shaco"
local socket = require "socket"

local tunnel = {}

local sock
local addr

local function connect(response)
    assert(addr, 'tunnel address is nil')
    response('Tunnel to '..addr)
    sock = assert(socket.connect(addr))
    shaco.fork(function()
        socket.readon(sock)
        while true do
            local data, info = socket.read(sock, '\n')
            if data then
                response(data)
            else
                response('Tunnel broken: '..info)
                break
            end
        end
        socket.close(sock)
        sock = nil
    end)
end

function tunnel.init(response, ...)
    if not sock then
        addr = ...
        connect(response)
    else
        response('Tunnel already exist')
    end
end

function tunnel.fini()
    if sock then
        socket.close(sock)
        sock = nil
    end
end

function tunnel.handle(response, cmdline)
    if not sock then
        connect(response)
    end
    if sock then
        socket.send(sock, cmdline..'\n')
    end
end

return tunnel
