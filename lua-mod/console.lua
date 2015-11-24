local shaco = require "shaco"

local CMD = {}

function CMD.launch(args)
    assert(shaco.luaservice(args[1]))
end

shaco.start(function()
    local function execute()
        local cmdline = io.stdin:read()
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
                error("unknown cmd: "..args[1])
            end
        end
    end

    while true do
        local status, err = pcall(execute)
        if not status then
            print (err)
        end
    end
end)
