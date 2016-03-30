local shaco = require "shaco"
local socket = require "socket"

shaco.start(function()
    shaco.timeout(180*1000, function()
        os.exit(2)
    end)
    local function resolve(host)
        local f = io.popen("./resolveip -t 60 "..host, "r")
        for v in f:lines("l") do
            f:close()
            return v
        end
        f:close()
    end
    local ok, err = pcall(function()
        local host = shaco.getenv("host") or "127.0.0.1:18001"
        local ip1 = resolve("sdk.g.uc.cn")
        local ip2 = resolve("openapi.360.cn")
        print(ip1)
        print(ip2)
        local id = assert(socket.connect(host))
        socket.readon(id)
        assert(socket.send(id, ":game sdkhost uc "..ip1.."\n"))
        print(assert(socket.read(id)))
        assert(socket.send(id, ":game sdkhost 360 "..ip2.."\n"))
        print(assert(socket.read(id)))
        socket.close(id)
        os.exit(0)
    end)
    if not ok then
        print(err)
        os.exit(1)
    end
end)
