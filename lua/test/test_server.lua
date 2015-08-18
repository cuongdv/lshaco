local shaco = require "shaco"
local socket = require "socket"

local host = "127.0.0.1:1234"
local ip, port = string.match(host, "([^:]+):?(%d+)$")

local function client(id)
    print("accept client:", id)
    socket.start(id)
    socket.readenable(id, true)
    while true do
        local line = assert(socket.read(id, "*l"))
        --print("write line", line)
        socket.send(id, line.."\n") 
    end
end

shaco.start(function()
    local id = assert(socket.listen(ip, port))
    socket.start(id, function(id)
        shaco.fork(client, id)
    end)
    print(string.format("listen on %s:%s", ip, port))
end)
