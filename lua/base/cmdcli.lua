local shaco = require "shaco"
local socket = require "socket"
local linenoise = require "linenoise"

shaco.start(function()
    local history_file = ".cmdcli.history"
    local host = shaco.getenv("host") or "127.0.0.1:18001"
    local ip, port = host:match("([^:]+):?(%d+)$")
    local single_command = shaco.getenv("command")
    local id = assert(socket.connect(ip, tonumber(port)))
    socket.readenable(id, true)

    local function encode(s)
        return string.char(
            bit32.extract(#s,0,8),
            bit32.extract(#s,8,8))..s
    end
    
    local function rpc(s)
        socket.send(id, encode(s))
        while true do
            local h = assert(socket.read(id, "*2"))
            local c = assert(socket.read(id, h))
            if c == "." then
                return
            end
            print(c)
        end
    end
    
    local function interact()
        if not id then
            id = assert(socket.connect(ip, tonumber(port)))
            socket.readenable(id, true)
        end
        while true do
            local s = linenoise.linenoise("> ")
            if s == nil then
                linenoise.savehistory(history_file)
                os.exit(1)
            end
            s = string.match(s, "^%s*(.-)%s*$")
            if s ~= "" then
                rpc(s)
                linenoise.addhistory(s)
            end
        end
    end

    if single_command then
        rpc(single_command)
        os.exit(1)
    end
    rpc("hi")
    linenoise.loadhistory(history_file)
    while true do
        local ok, err = pcall(interact)
        if not ok then
            print ('[error]'..err..', wait to connect ...')
            shaco.sleep(1000)
            socket.close(id)
            id = nil
        end
    end
end)
