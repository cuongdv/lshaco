local shaco = require "shaco"
local sfmt = string.format
local mod = require "mod"
local mod2 = require "mod2"
local tbl = require "tbl"

local m = mod.new()
print(m)
local mm = mod.new()
local m2 = mod2:new()
print(m2)

local t1, t2, sum

t1 = shaco.time()
for i=1, 10000000 do
    --m:add(1)
end
t2 = shaco.time()
shaco.info(sfmt("mod use time %d", t2-t1))

t1 = shaco.time()
for i=1, 10000000 do
    --m2:add(1)
end
t2 = shaco.time()
shaco.info(sfmt("mod2 use time %d", t2-t1))
m:add(1)
m2:add(2)
print(m)
print(m2)
print(mod)
print(mod2)
tbl.print(m, "mod", shaco.trace)
tbl.print(m2, "mod2", shaco.trace)
tbl.print(mod, "mod", shaco.trace)
tbl.print(mod2, "mod2", shaco.trace)

local m22 = m2:new()
print(m22)


print(m.add)
print(mm.add)
