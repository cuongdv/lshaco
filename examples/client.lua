local shaco = require "shaco"
local socket = require "socket"

local nclient, nmsg = ...

local function client(addr)
    local id = assert(socket.connect(addr))
    socket.readon(id)
    for i=1,nmsg do
        socket.send(id, i..'\n')
        local ok, s = pcall(function()
            return assert(socket.read(id, '\n'))
        end)
        print (id, s)
        --assert(s==tostring(i))
    end
    socket.send(id, 'exit\n')
    local ok, err = pcall(function()
        assert(socket.read(id, '\n'))
    end)
    print (id, '[close]')
    socket.close(id)
end

shaco.start(function()
    for i=1, nclient do
        shaco.fork(client, '127.0.0.1:1234')
    end
end)
