local socket = require "socket"

local client = {}

local sock

function client.init(response)
    client.fini()
    local addr = '127.0.0.1:1234'
    response('client connect '..addr)
    sock = assert(socket.connect(addr))
    socket.readon(sock)
end

function client.fini()
    if sock then
        socket.close(sock)
        sock = nil
    end
end

function client.handle(response, cmdline)
    local ok, info = pcall(function()
        if not sock then
            client.init()
        end
        assert(socket.send(sock, cmdline..'\n'))
        response((assert(socket.read(sock, '\n'))))
    end)
    if not ok then
        print (info)
        response(info)
        client.fini()
    end
end

return client
