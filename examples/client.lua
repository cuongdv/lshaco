local shaco = require "shaco"
local socket = require "socket"

local client = {}

local sock
local addr

local function connect(response)
    response('Client connect '..addr)
    sock = assert(socket.connect(addr))
    shaco.fork(function()
        socket.readon(sock)
        while true do
            local data, info = socket.read(sock, '\n')
            response(data)
            if not data then
                break
            end
        end
        socket.close(sock)
        sock = nil
    end)
end

function client.init(response, ...)
    if not sock then
        addr = ...
        connect(response)
    else
        response('Client already exist')
    end
end

function client.fini()
    if sock then
        socket.close(sock)
        sock = nil
    end
end

function client.handle(response, cmdline)
    if not sock then
        connect(response)
    end
    if sock then
        socket.send(sock, cmdline..'\n')
    end
end

return client
