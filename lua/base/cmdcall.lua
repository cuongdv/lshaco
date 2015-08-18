local shaco = require "shaco"
local string = string
local table = table
local select = select

local function _R(source, id, result, pure)
    shaco.send(source, shaco.pack(id, "RES", result, pure))
end

local function cmdcall(CMD, source, id, s)
    local args = {}
    for w in string.gmatch(s, "%g+") do
        table.insert(args, w)
    end
    if #args > 0 then
        if string.byte(args[1], 1, 1) ==58 then 
            if #args > 1 then
                local handle = shaco.queryid(string.sub(args[1], 2))
                if handle then
                    shaco.sendraw(0, source, handle, shaco.PTYPE_CMD, 
                        shaco.pack(id, table.concat(args, ' ', 2)))
                else
                    _R(source, id, "no found handle")
                end
            else
                _R(source, id, "no assign command")
            end
        else
            local fun = CMD[args[1]]
            if fun then
                _R(source, id, select(2, pcall(fun, select(2, table.unpack(args)))))
            else
                _R(source, id, "no found command")
            end
        end
    else
        _R(source, id, "no input")
    end
end

return cmdcall
