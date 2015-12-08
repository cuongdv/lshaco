local shaco = require "shaco"
local socket = require "socket"
local socketchannel = require "socketchannel"

local function test(sc, n, times)
    print(string.format("[%d] create", n), coroutine.running())
    for i=1,times do
        local resp = sc:request(
            string.format('%d:%d\n', n, i), 
            function(id)
                assert(false)
                return assert(socket.read(id, "\n"))
            end)
        print(string.format("[%d] read %s", n, resp))
    end 
end

shaco.start(function()
    local sc = assert(socketchannel.create{
        host = '127.0.0.1:1234',
        --auth = nil,
    })
    sc:connect()
    local times = 1
    print ("fork 1")
    for i=1, 10 do
        shaco.fork(test, sc, i, times)
    end
    print("------------------------------")
end)
