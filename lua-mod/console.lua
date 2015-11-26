local shaco = require "shaco"
local socket = require "socket"

local CMD = {}

function CMD.start(args)
    assert(shaco.luaservice(args[1]))
end

function CMD.stop(args)
end

shaco.start(function()
    local id = assert(socket.stdin())
    while true do 
        local cmdline = assert(socket.read(id, "*a"))
        local args = {}
        for w in string.gmatch(cmdline, '[%w_]+') do
            table.insert(args, w)
        end
        if #args > 0 then
            local func = CMD[args[1]]
            if func then
                table.remove(args, 1)
                func(args)
            else
                print("unknown cmd: "..args[1])
            end
        end
    end
end)
