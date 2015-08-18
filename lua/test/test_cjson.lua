local cjson = require "cjson"
 
local str = '["a", "b", "c"]'
local j = cjson.decode(str)
for i,v in ipairs(j) do
    print(v)
end
 
str = '{"A":1, "B":2}'
j = cjson.decode(str)
for k,v in pairs(j) do
    print(k..":"..v)
end
j['C']='c'
local new_str = cjson.encode(j)
print(new_str)
