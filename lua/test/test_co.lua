local sfmt = string.format

local t = {}
local co1 = coroutine.create(function() 
    print("1")
    print("2")
    print("3")
    print("4")
    print("5")
    print("6")
    local a = {10}
    t["a"] = a
    coroutine.yield()
    print("--------------" .. t["a"])
    print("7")
    print("8")
    print("9")
    print("10")
end)
local co2 = coroutine.create(function() 
    print("a")
    t["a"] = 100
    coroutine.yield()
    print("b")
end)

print(co1)
print(co2)

local function resume(co)
    local ok, err = coroutine.resume(co)
    if not ok then
        print(err)
    end
end
resume(co1)
resume(co2)
resume(co1)
--print(coroutine.status(co))
--print(coroutine.resume(co))
--print(coroutine.status(co))

