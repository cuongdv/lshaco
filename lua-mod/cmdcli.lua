local shaco = require "shaco"
local socket = require "socket"
local linenoise = require "linenoise"

shaco.start(function()
    local history_file = ".cmdcli.history"
    local host = shaco.getenv("host") or "127.0.0.1:18001"
    local stdin = assert(socket.stdin())
    local sockid

    linenoise.loadhistory(history_file) 
    while true do
        local prompt = sockid and host or 'not connected'
        local s = linenoise.read(prompt..'> ',
            function() return socket.read(stdin, 1) end,
            function() return io.stdin:read("l") end)
        if s == nil then
            break
        end
        s = string.match(s, "^%s*(.-)%s*$")
        if s ~= "" then
            local ok, err = pcall(function()
                if not sockid then
                    sockid = assert(socket.connect(host))
                    socket.readon(sockid)
                end
                assert(socket.send(sockid, s..'\n'))
                io.stdout:write(assert(socket.read(sockid)))
                io.stdout:flush()
            end)
            if not ok then
                sockid = false
            end
        end
    end
    linenoise.savehistory(history_file)
    shaco.abort()
end)
