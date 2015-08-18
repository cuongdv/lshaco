local shaco = require "shaco"
local socket = require "socket"
local linenoise = require "linenoise"

shaco.start(function()
    local history_file = ".cc.history"
    local host = shaco.getenv("host") or "127.0.0.1:7997"
    local ip, port = host:match("([^:]+):?(%d+)$")
    local single_command = shaco.getenv("command")
    local id = assert(socket.connect(ip, tonumber(port)))
    socket.readenable(id, true)

    local function read(id)
        local r = assert(socket.read(id, "\r\n"))
        while r ~= "chicken node>" do
            print(r)
            r = assert(socket.read(id, "\r\n"))
        end
    end

    local function rpc(s)
        --print ("[send] "..s)
        assert(socket.send(id, s))
        read(id)
    end
   
    read(id)
    if single_command then
        rpc(single_command..'\r\n')
        os.exit(1)
    end
    linenoise.loadhistory(history_file)
    while true do
        local s = linenoise.linenoise("> ")
        if s == nil then
            linenoise.savehistory(history_file)
            os.exit(1)
        end
        s = string.match(s, "^%s*(.-)%s*$")
        if s ~= "" then
            local ok, err = pcall(rpc, s..'\r\n')
            if not ok then
                print (err)
                socket.close(id)
                id, err = socket.connect(ip, tonumber(port))
                if id then
                    print ("[reconnect] ok")
                    socket.readenable(id, true)
                    rpc(s..'\r\n')
                else
                    print("[reconnect] "..err)
                end
            end
            linenoise.addhistory(s)
        end
    end
end)
