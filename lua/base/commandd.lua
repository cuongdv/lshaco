local shaco = require "shaco"
local socket = require "socket"
local util = require "util.c"

assert(util.setenv("PYTHONIOENCODING", "utf-8"))

local path = ".."

local function exec(id, command)
    local f = io.popen(command, "r")
    local result = f:read("*l")
    while result do
        result = util.iconv(result, "gbk", "utf-8")
        assert(socket.send(id, result.."\n"))
        result = f:read("*l")
    end
    f:close()
end

local CMDS = {}
CMDS.status = {
    string.format('cd %s && ./shaco-foot ls', path)
}
CMDS.update_res = {
    string.format('cd %s && make res', path),
    string.format('cd %s && ./shaco config_cmdcli --command ":game reloadresall"', path.."/bin"),
}
CMDS.restart = {
    string.format('cd %s && ./shaco-foot restart game', path)
}

shaco.start(function()
    local host = shaco.getenv("host") or "0.0.0.0:7999"
    local ip, port = host:match("^([^:]+):?(%d+)$")
    local lid = assert(socket.listen(ip, port))
    socket.start(lid, function(id)
        shaco.fork(function()
            socket.start(id)
            socket.readenable(id, true)
            shaco.info(string.format("client[%d]: login",id))
            local cmd = assert(socket.read(id, "*l"))
            local cl  = CMDS[cmd]
            if cl then
                for _, c in ipairs(cl) do
                    exec(id, c)
                end
                shaco.info(string.format("client[%d]: execute command `%s`",id,cmd))
            else
                shaco.info(string.format("client[%d]: unfound command `%s`",id,cmd))
            end
            socket.shutdown(id)
        end)
    end)
end)
