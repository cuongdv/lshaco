local shaco = require "shaco"
local tinsert = table.insert
local sfmt = string.format

local times = 100000
local t1, t2, sum

local l1 = {}
t1 = shaco.time()
for i=1, times do
    tinsert(l1, i)
end
t2 = shaco.time()
shaco.info(sfmt("tinsert use time %d", t2-t1))

local l2 = {}
t1 = shaco.time()
for i=1, times do
    l2[#l2+1] = i
end
t2 = shaco.time()
shaco.info(sfmt("t[] use time %d", t2-t1))

local l3 = {}
t1 = shaco.time()
for i=1, times do
    rawset(l3, #l3+1, i)
end
t2 = shaco.time()
shaco.info(sfmt("rawset use time %d", t2-t1))
