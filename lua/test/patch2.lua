local tinsert = table.insert
local sfmt = string.format
local patch = require "patch"
local patch_add = patch.add

local mod2 = {}

--local proto = {}
--local mt = {
    --__index = proto,
    --__tostring = function(self)
        --return sfmt("[mod2:%s:%d]", self.name, self.i)
    --end,
--}
function mod2:__tostring()
    return sfmt("[mod2:%s:%d]", self.name, self.i)
end


function mod2:new(t)
    local t = t or {}
    t.name = "abc"
    t.i = 10
    setmetatable(t, self)
    self.__index = self
    return t
end

function mod2:add(a)
    --print(sfmt("call add, i=%d", self.i))
    return patch_add(a, a)
end

function mod2:dump()
    print("kkkk")
end

return mod2
