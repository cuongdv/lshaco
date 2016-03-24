local shaco = require "shaco"
local socket = require "socket"
local linenoise = require "linenoise"

print([[
    ______________________________________________
    |              WELCOME TO CMD CLI            |
    ______________________________________________
    ]])

shaco.start(function()
    local history_file = ".cmdcli.history"
    local host = shaco.getenv("host") or "127.0.0.1:18001"
    local single_command = shaco.getenv("command")
    local stdin = assert(socket.stdin())
    local sockid

    local function Error(s) io.stderr:write("\x1b[31m"..s.."\x1b[0m") end
    local function Warn(s)  io.stderr:write("\x1b[33m"..s.."\x1b[0m") end
    local function Info(s)  io.stderr:write("\x1b[32m"..s.."\x1b[0m") end

    local function block_connect()
        Warn("+Connecting ... ")
        local i=0
        while true do
            local id = socket.connect(host)
            if id then
                socket.readon(id)
                Info("OK\n")
                return id
            end
            i=i+1
            if i>3 then break end
            shaco.sleep(1000)
        end
        Error("FAILED\n")
    end

    local function reader()
        while true do
            if sockid then
                local data = socket.read(sockid)
                if data then
                    io.stdout:write(data)
                else
                    Error("*Disconnect*\n")
                    sockid = false
                end
            else
                shaco.sleep(10)
            end
        end
    end

    local function interact()
        linenoise.loadhistory(history_file) 
        while true do
            local s = linenoise.read(function()
                return socket.read(stdin, 1)
            end)
            if s == nil then
                break
            end
            s = string.match(s, "^%s*(.-)%s*$")
            if s ~= "" then
                if not sockid then
                    sockid = block_connect()
                end
                if sockid then
                    socket.send(sockid, s..'\n')
                end
            end
        end
        linenoise.savehistory(history_file)
    end
    
    if single_command then
        Error("Not support now\n")
    else
        shaco.fork(reader)
        interact()
    end
    os.exit(1)
end)
