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
            -- s:decode first (debug this in ios recharge cehck d:)
            local data = s:decode()
            if data and data ~= "" then
                return data
            end
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
        --print("--- send", #data)
        s:encode(data)
        while true do
            --print ("--- s:encode ok")
            data = s:read()
            if not data then
                break
            end
            --print ("--- s:read", #data)
            local ok = socket.send(id, data)
            if not ok then
                error(socket_error)
            end
        end
    end
end

return sslsocket
