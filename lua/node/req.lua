local REQ = {}
function REQ.__REG(l)
    for _, h in ipairs(l) do
        assert(string.sub(h, 1, 2) == "h_")
        local t = require(h)
        assert(type(t) == "table")
        for id, fun in pairs(t) do
            assert(type(id) == "number" or type(id) == "string")
            assert(type(fun) == "function")
            REQ[id] = fun
        end
    end
end
return REQ
