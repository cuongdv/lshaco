local shaco = require "shaco"
local redis = require "redis"
local tbl = require "tbl"

local conf = {
    host = "127.0.0.1",
    port = 6379,
    db = 1,
}
shaco.start(function()
    local times = 100000
    local db = redis.connect(conf)

    local function bm(times, func)
        local t1 = os.clock()
        for i=1, times do
            func()
        end
        local t2 = os.clock()
        print(string.format("use time: %.3f, qps: %.3f", t2-t1, times/(t2-t1)))
    end
    bm(times, function() 
        assert(db:ping() == "PONG") 
    end)
    db:close()
end)
