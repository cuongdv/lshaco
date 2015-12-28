--[[
echo server
1. echo received line string
2. close socket when received 'exit'
]]

local shaco = require "shaco"
local socket = require "socket"

shaco.start(function()
    local addr = shaco.getenv('addr') or ('127.0.0.1:1234')
    local sock = assert(socket.listen(
        addr, function(id)
            print (id, '[new socket]')
            socket.start(id)
            socket.readon(id)
            while true do
                local ok, s = pcall(function()
                    return assert(socket.read(id, '\n'))
                end)
                if not ok then
                    print (id, s)
                    break
                end
                print (id, s)
                if s == 'exit' then
                    break
                end
                socket.send(id, s..'\n')
            end
            socket.close(id, false)
            print (id, '[close]')
        end))
    print('listen on '..addr, sock, socket.getfd(sock))
end)
