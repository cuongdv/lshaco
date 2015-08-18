local tinsert = table.insert
local sfmt = string.format

local mod = {}
local proto = {}
local mt = {
    __index = proto,
    __tostring = function(self)
        return sfmt("[mod:%s:%d]", self.name, self.i)
    end,
}

function mod.new(t)
    local t = t or {}
    t.name = "abc"
    t.i = 10
    return setmetatable(t, mt)
end

function proto:add(a)
    self.i = self.i + a
    --print(sfmt("call add, i=%d", self.i))
end

function proto:dump()
    for i, v in ipairs(l) do
        print(i .. ":" .. v)
    end
end

return mod
