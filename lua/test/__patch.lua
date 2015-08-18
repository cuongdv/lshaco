
--local sumextra2 = 10
--local sumextra = 0
--local t = {}

--function t.sum(a, b)
    --return a*b+sumextra2+sumextra
--end

--return t

local t = {}
local sumextra = 0

function t.add(a, b)
    return a+b+10+sumextra
end

return t
