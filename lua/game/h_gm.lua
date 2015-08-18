local GM = require "gm"
local string = string
local table = table

local REQ = {}

REQ[IDUM_GM] = function(ur, v)
    local args = {}
    for v in string.gmatch(v.command, "[%w_]+") do
        table.insert(args, v)
    end
    if #args >= 1 then
        local f = GM[args[1]]
        if f then
            f(ur, args)
        end
    end
end

return REQ
