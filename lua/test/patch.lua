
local sumextra = 0
local t = {}

function t.sum(a, b)
    return a+b+sumextra
end

function t.sum2(a, b)
    return t.sum(a, b)
end

function t.add(a, b)
    
    local i = a+b+sumextra
    sumextra = sumextra+1
    return i
end

return t

