local shaco = require "shaco"

local aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa = 1
print("=====================================================================1")
for k, v in pairs(_G) do
    print(k .. "->" .. tostring(v))
end
print("=====================================================================2")
for k, v in pairs(_ENV) do
    print(k .. "->" .. tostring(v))
end

print("=====================================================================3")
for k, v in pairs(package.loaded) do
    print(k .. "->" .. tostring(v))
end

print("=====================================================================4")
--for k, v in pairs(shaco) do
    --print(k .. "->" .. tostring(v))
--end
