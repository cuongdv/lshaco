local sfmt = string.format

setmetatable(_ENV, {
    --__index = _ENV,
    __index = function(_, k)
        error(sfmt("attempt to read undeclared variable `%s`", k), 2)
    end,
    __newindex = function(_, k)
        error(sfmt("attempt to write undeclared variable `%s`", k), 2)
    end,
})

local mod = require "test.mod"

local m = mod.new()
print(m)

--IDUM_K = 1
rawset(_ENV, "IDUM_K", 2)
--print(IDUM_K)
IDUM_K = 10
print(IDUM_K)

if rawget(_ENV, 'kk') then
    print("==========")
end
