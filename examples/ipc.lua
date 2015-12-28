local shaco = require "shaco"
local socket = require "socket"
local socket_c = require "socket.c"

shaco.start(function()
    io.open('1.txt', 'a+')
    local fd0, fd1 = assert(socket_c.pair())
    local id0 = socket.bind(fd0, 'IPC')
    local id1 = socket.bind(fd1, 'IPC')
    print ('socketpair:', fd0, fd1)
    print ('socketpair:', id0, id1)
    socket.readon(id0)
    socket.readon(id1)
    print(socket.ipc_sendfd(id0, 4, '1234\n'))
    print(socket.ipc_readfd(id1, '\n'))
    print ('------ ok')
end)
