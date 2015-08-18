local tbl = require "tbl"

local tmp = {
    [1] = {a=1, b=2},
    [2] = {a=10,b=20}
}
function read_only(t)
    --local proxy = {}
    local mt = {
        --__index = t,
        __newindex = function(t, k, v)
            error("attempt to update a read-only table", 2)
        end
    }
    setmetatable(t, mt)
    --return proxy
end

function read_only_r(t)
    read_only(t)
    tbl.print(t, "sdfsdfdf", shaco.trace)
    for _, v in ipairs(t) do
        print(v)
        if type(v) == "table" then
            print("----------------------------")
            read_only(v)
        end
    end
    --return t--read_only(t)
end
read_only(tmp)
print(tmp[1])
tmp[1] = 123
--tmp[1].a = 2
--


--local t = {
    --__index = function(p)
        --print("---parent table:")
        --print(p)
    --end
--}
--local t1 = {}
--print("---t1:")
--print(t1)
--setmetatable(t1, t)
--print("---visit t1:")
--print(t1[1])

--local t2 = {}
--print("---t2:")
--print(t2)
--setmetatable(t2, t)
--print("---visit t2:")
--print(t2[1])

--print("------------------------------")
--print(t1[1])

