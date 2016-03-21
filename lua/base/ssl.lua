local core = require "ssl.c"
local socket = require "socket"
local http = require "http"
local sslsocket = require "sslsocket"

local ssl = {}

local function handshake(id, s)
    local ok, want = s:handshake()
    while not ok do
        if want == "read" then
            local data = s:read()
            if data then
                --print ("read size:"..#data)
                socket.send(id, data)
            else
                --print ("read empty, so socket read...")
                local data = socket.read(id, '*a')
                --print ("socket read:"..#data)
                s:write(data)
            end
        elseif want == "write" then

        end
        ok, want = s:handshake()
    end
end

function ssl.request(id, host, uri, headers, form)
    local s = core.new()
    s:connect()
    handshake(id, s)
    --print ("handshake ok")
    
    return http.request("POST", host, uri, headers, form, 
            sslsocket.reader(id, s),
            sslsocket.sender(id, s))

end

return ssl
