local shaco = require "shaco"
local socket = require "socket"

local function read(id, mode)
    if mode == "*1" or mode == "*2" or mode == "*4" then
        local h = assert(socket.read(id, mode))
        local s = assert(socket.read(id, h))
        return s
    else
        local s = assert(socket.read(id, mode))
        return s
    end
end

local function client(id)
    print("accept client:", id)
    socket.start(id)
    socket.readenable(id, true)
    local mode = read(id, "*l")
    print(string.format("message mode: %s", mode))
    while true do
        local s = read(id, mode)
        print (s)
    end
end

shaco.start(function()
    local host = shaco.getenv("host")
    local ip, port = string.match(host, "([^:]+):?(%d+)$")
    local id, err = socket.listen(ip, port)
    assert(id, err)
    socket.start(id, function(id)
        shaco.fork(client, id)
    end)
    print("listen on ",host)
end)
