local socket = require "socket"

local sslsocket = {}

local socket_error = setmetatable({}, {
    __tostring = function()
        return "[ssl socket error]"
    end})

function sslsocket.reader(id, s)
    return function(format)
        local i=0
        while true do
            -- todo s:decode first
            --print ("------------------"..i)
            local data = socket.read(id, format)
            if data then
                --print ("--write size:"..#data)
                s:write(data)
                data = s:decode()
                if not data then
                    error(socket_error)
                end
                if data ~= "" then
                    --print ("--decode size:"..#data)
                    return data
                end
            else
                error(socket_error)
            end
            i=i+1
        end
    end
end

function sslsocket.sender(id, s)
    return function(data)
        s:encode(data)
        data = s:read()
        local ok = socket.send(id, data)
        if not ok then
            error(socket_error)
        end
    end
end

return sslsocket
