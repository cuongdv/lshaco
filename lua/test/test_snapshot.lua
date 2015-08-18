local snapshot = require "snapshot"

local function fun()
    local tmp2 = {}
end

local s1 = snapshot()
local tmp1
local tmp = {}
tmp1 = tmp
fun()
local s2 = snapshot()

for k, v in pairs(s2) do
    if s1[k] == nil then
        print(k, v)
        --print(k, v)
    end
end
