local shaco = require "shaco"
local socket = require "socket"
local socketchannel = require "socketchannel"

local host = "127.0.0.1:1234"
local ip, port = string.match(host, "([^:]+):?(%d+)$")

local data = string.rep("1", 1024)

local function channel(sc, times)
    local t1, t2
    t1 = shaco.now()
    local n = 0
    for i=1,times do
        assert(sc:request(data.."\n", function(id)
            return assert(socket.read(id, "*l"))
        end) == data)
        n=n+1
    end
    t2 = shaco.now()
    print(string.format("Times %d use time: %d", times, t2-t1))
end

shaco.start(function()
    local times = shaco.getenv("times") or 10000
    local chans = shaco.getenv("chans") or 1
    print (string.format("Test times %d in chans %d", times, chans))
    local sc = assert(socketchannel.create(ip, port))
    for i=1,chans do
        shaco.fork(channel, sc, times/chans)
    end
    sc:holdon()
end)
