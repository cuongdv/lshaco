local shaco = require "shaco"
local socket = require "socket"
local commandline = require "commandline"
local linenoise = require "linenoise"

local console = {}

shaco.start(function()
    local path = shaco.getenv('console_expandpath') or './lua-mod/expand/?.lua'
    commandline.expand_path(path)
 
    -- stdin
    if tonumber(shaco.getenv('daemon')) ~=1 then 
        local reader = function()
            local id = assert(socket.stdin())
            return function()
                return linenoise.read('',
                    function() return socket.read(id, 1) end,
                    --todo why this do not work ?
                    --function() return socket.read(id, "\n") end)
                    function() return io.stdin:read("l") end)
            end
        end
        shaco.fork(function(...)
            linenoise.history(tonumber(shaco.getenv('console_historymax')))
            local history_file = shaco.getenv('console_historyfile')
            if history_file then
                linenoise.loadhistory(history_file)
            end
            commandline.loop(...)
            if history_file then
                linenoise.savehistory(history_file)
            end
            shaco.abort('by console')
        end, reader(), print)
    end
    -- harbor
    --if tonumber(shaco.getenv('slaveid')) then
    --    local co_commandline
    --    local read = function()
    --        co_commandline = coroutine.running()
    --        shaco.wait()
    --        co_commandline = nil
    --        return _result
    --    end
    --    local response = function(...)
    --        -- todo to slave
    --    end
    --    shaco.fork(commandline.loop, read, response)
    --    shaco.fork(function()
    --        while true do
    --            shaco.wait()
    --            if co_commandline then
    --                shaco.wakeup(co_commandline)
    --            else
    --                -- todo error
    --            end
    --        end
    --    end)
    --end

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
                    return socket.read(id, '\n')
                end
                local response = function(...)
                    socket.send(id, table.concat({...}, ' ')..'\n')
                end
                commandline.loop(read, response)
                socket.close(id)
            end))
    end
end)
