local shaco = require "shaco"
local socket = require "socket"

local function sendpackage(id, s)
    assert(socket.send(id, string.pack('>I2', #s)..s))
end

local function client1(addr)
    print ('client1 '..addr)
    local id = assert(socket.connect(addr))
    socket.readon(id)
    sendpackage(id, "1234567890")
    sendpackage(id, "")
    socket.close(id)
end

local function client2(addr)
    print ('client2 '..addr)
    local id = assert(socket.connect(addr))
    socket.readon(id)
    sendpackage(id, "1234567890")
    sendpackage(id, "123456")
    socket.close(id)
end

local function client3(addr)
    print ('client3 '..addr)
    local id = assert(socket.connect(addr))
    socket.readon(id)
    assert(socket.send(id, string.pack('>I2', 0).."890"))
    socket.close(id)
end


shaco.start(function()
    local addr = '127.0.0.1:1234'
    shaco.fork(client1, addr)
    shaco.fork(client2, addr)
    shaco.fork(client3, addr)
end)
