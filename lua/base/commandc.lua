local shaco = require "shaco"
local socket = require "socket"
local linenoise = require "linenoise"

shaco.start(function()
    shaco.fork(function()    
        local function command(cmd)
            local host = shaco.getenv("host") or "0.0.0.0:7999"
            local ip, port = host:match("([^:]+):?(%d+)$")
            local id = assert(socket.connect(ip, tonumber(port)))
            socket.readenable(id, true)
          
            assert(socket.send(id, cmd.."\n"))
            while true do
                local result, err = socket.read(id, "*a")
                if result then
                    print (result)
                else break
                end
            end
        end

        local history_file = ".commandc.history"
        linenoise.loadhistory(history_file)
        while true do
            local s = linenoise.linenoise("> ")
            if s == nil then
                linenoise.savehistory(history_file)
                os.exit(1)
            end
            s = string.match(s, "^%s*(.-)%s*$")
            if s ~= "" then
                command(s)
                linenoise.addhistory(s)
            end
        end
    end)
end)
