local socket = require "socket"
local core = require "ssl.c"

local ssl = {}

function ssl.connect()
    local s = core.new()
    s:connect()
    return s
end

function ssl.handshake(id, s)
    local ok, want = s:handshake()
    while not ok do
        if want == "read" then
            local data = s:read()
            if data then
                --print ("read size:"..#data)
                socket.send(id, data)
            else
                --print ("read empty, so socket read...")
                local data = socket.read(id)
                --print ("socket read:"..#data)
                s:write(data)
            end
        elseif want == "write" then

        end
        ok, want = s:handshake()
    end
end

return ssl
