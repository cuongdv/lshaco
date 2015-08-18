local snapshot = require "snapshot"

local function fun()
    local tmp2 = {}
end

local S1 = snapshot()

local tmp = {}
fun()
local S2 = snapshot()

for k,v in pairs(S2) do
	if S1[k] == nil then
		print(k,v)
	end
end

