local shaco = require "shaco"
local socket = require "socket"
local socketchannel = require "socketchannel"

local times, chans = ...
local data = string.rep("1", 1024)

local function channel(sc, n, times)
    local t1, t2
    t1 = shaco.now()
    for i=1,times do
        assert(sc:request(data.."\n", function(channel)
            return true, channel:read("\n")
        end) == data)
    end
    t2 = shaco.now()
    print(string.format("[%d]times %d use time: %d", n, times, t2-t1))
end

shaco.start(function()
    times = times or 100000
    chans = chans or 10
    local sc = assert(socketchannel.create{
        host='127.0.0.1:1234',
    })
    for i=1,chans do
        shaco.fork(channel, sc, i, times//chans)
    end
    print(string.format("Test times %d in chans %d", times, chans))
end)
