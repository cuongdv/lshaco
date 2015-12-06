local shaco = require "shaco"
local tbl = require "tbl"
local patch = require "patch"
local hotfix = require "hotfix"
local tpcreaterole = require "__tpcreaterole"
local patch2 = require "patch2"
local myadd = patch.add

local session = 10
local session2 = 11
local function lfun(a, b)
    local sum = 100 
    return sum + a*b + session + session2
end

tbl.print(debug.getinfo(lfun))
tbl.print(debug.getinfo(lfun, "n"))

local i=0
while true do
    local info = debug.getinfo(i)
    if info == nil then
        break
    end
    tbl.print(info)
    i = i+1
end

print("---------------------getupvalue---------------------")
i=1
while true do
    local name, value = debug.getupvalue(lfun, i)
    if not name then
        break
    end
    i = i+1
    print(name, value)
end

print("----------------------hotfix--------------------")

local f, err = loadfile("../lua/test/__patch.lua")
assert(f, err)
i=1
while true do
    local name, value = debug.getupvalue(f, i)
    if not name then
        break
    end
    i = i+1
    print(name, value)
end

local p2 = patch2:new()
assert(patch.add(2,3)==5)
assert(p2:add(1)==3)
assert(myadd(2,3)==7)
--+3
hotfix("patch", "../lua/test/__patch.lua", "U")
assert(patch.add(2,3)==18)
assert(p2:add(1)==15)
assert(myadd(2,3)==8) --+4
local p22 = patch2:new()
assert(p22:add(1)==16)

--print("=====================================================================")
--for k, v in pairs(package.loaded) do
    --print(k .. "->" .. tostring(v))
--end

--print("+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++")

--local function func()
    --mysum(1,2)
--end

--print(mysum)
--print(patch.sum)
--print(func)
--print(debug.upvalueid(func, 1))
--print(debug.getupvalue(func, 1))

--print(tpcreaterole)

--local function tp_fun()
    --tbl.print(tpcreaterole, "kk")
--end

--tp_fun()

--local tp = {1,2,3}

--i=1
--while true do
    --local upn, upv = debug.getupvalue(tp_fun, i)
    --if not upn then
        --break
    --elseif upv == package.loaded["__tpcreaterole"] then
        --assert(debug.setupvalue(tp_fun, i, tp)=="tpcreaterole")
        --break
    --end
    --i=i+1
--end
--tbl.print(package.loaded["__tpcreaterole"], "kkkk")
--tp_fun()

--print("========================for table===========================")

----local mod = require "mod"
----for k, v in pairs(mod) do
    ----print(k, v)
----end

--local mod2 = require "mod2"
--for k, v in pairs(mod2) do
    --print(k, v)
--end
--local mm = mod2:new()
--mod2.dump()
--mm:dump()
--print(mod2.dump)
--function mod2:dump()
    --print("fffff")
--end
--print(mod2.dump)
--mod2.dump()
--print(mm.dump)
--mm:dump()
--print(package.loaded["mod2"]["dump"])

