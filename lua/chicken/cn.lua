local shaco = require "shaco"
local socket = require "socket"

local function send(id, s)
    local l = #s
    s = string.char(l&0xff, (l>>8)&0xff)..s
    assert(socket.send(id, s))
end

local function exec(id, cmd)
    shaco.info ("[cmd] "..cmd)
    local f = io.popen(cmd, "r")
    local result = f:read("*l")
    shaco.info (result)
    while result do
        --result = util.iconv(result, "gbk", "utf-8")
        if #result > 0 then
            send(id, result)
        end
        result = f:read("*l")
        shaco.info (result)
    end
    send(id, "") -- end of package 
    shaco.info ("ok")
    f:close()
end

shaco.start(function()
    local host = shaco.getenv("host") or "127.0.0.1:7998"
    local ip, port = host:match("^([^:]+):?(%d+)$")
    while true do
        local ok, err = pcall(function()
            local id = assert(socket.connect(ip, port))
            shaco.info("[connected] "..host)
            socket.readenable(id, true)
            local cmd
            while true do
                cmd = assert(socket.read(id, "*l"))
                exec(id, cmd)
            end
        end)
        if not ok then
            shaco.error(err)
            shaco.sleep(3000)
        end
    end
end)
