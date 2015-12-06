local shaco = require "shaco"
local socket = require "socket"

local console = {}

function console.help()
    for k,v in pairs(console) do
        print('* '..k)
    end
end

function console.start(name)
    assert(shaco.luaservice(name))
end

shaco.start(function()
    local id = assert(socket.stdin())
    while true do 
        local cmdline = assert(socket.read(id))
        local args = {}
        for w in string.gmatch(cmdline, '[%w_]+') do
            table.insert(args, w)
        end
        if #args > 0 then
            local func = console[args[1]]
            if func then
                func(select(2, table.unpack(args)))
            else
                print("Unknown command "..args[1])
            end
        end
    end
end)
