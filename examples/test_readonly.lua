local shaco = require "base.shaco"
local sfmt = string.format
require "_taskdata"

local T1 = TASK
local t1, t2, a

t1 = shaco.time()
sum  = 0
for i=1, 10000000 do
    a = T1[10091]
end
t2 = shaco.time()
shaco.info(sfmt("table no readonly use time %d", t2-t1))


local function read_only(t)
    local proxy = {}
    local mt = {
        __index = t,
        __newindex = function(t, k, v)
            error("attempt to update a read-only table", 2)
        end
    }
    setmetatable(proxy, mt)
    return proxy
end

local T2 = read_only(T1)
t1 = shaco.time()
sum  = 0
for i=1, 10000000 do
    a = T2[10091]
end
t2 = shaco.time()
shaco.info(sfmt("table readonly use time %d", t2-t1))
