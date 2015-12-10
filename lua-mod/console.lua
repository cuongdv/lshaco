local shaco = require "shaco"
local socket = require "socket"
local commandline = require "commandline"
local linenoise = require "linenoise"

local console = {}

shaco.start(function()
    commandline.expand_path('./examples/?.lua')
   print (shaco.getenv('daemon'))
    -- stdin
    if tonumber(shaco.getenv('daemon')) ~=1 then
        local reader = function()
            local id = assert(socket.stdin())
            return function()
                return linenoise.read(id, function(...)
                    return assert(socket.read(...))
                end)
            end
        end
        local response = function(...)
            print(...)
        end
        commandline.start(reader(), response)
    end
    -- harbor
    if tonumber(shaco.getenv('slaveid')) then
        local co_commandline
        local read = function()
            co_commandline = coroutine.running()
            shaco.wait()
            co_commandline = nil
            return _result
        end
        local response = function(...)
            -- todo to slave
        end
        commandline.start(read, response)
        shaco.fork(function()
            while true do
                shaco.wait()
                if co_commandline then
                    shaco.wakeup(co_commandline)
                else
                    -- todo error
                end
            end
        end)
    end

    -- socket input
    local addr = shaco.getenv('console')
    if addr ~= '1' then
        shaco.info('Console listen on '..addr)
        local sock = assert(socket.listen(
            addr,
            function(id)
                socket.start(id)
                socket.readon(id)
                local read = function()
                    assert(socket.read(id, '\n'))
                end
                local response = function(...)
                    socket.send(id,...)
                end
                commandline.start(read, response)
                socket.close(id)
            end))
    end
end)
