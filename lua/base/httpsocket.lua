local socket = require "socket"

local httpsocket = {}

local socket_error = setmetatable({}, {
    __tostring = function()
        return "[http socket error]"
    end})

function httpsocket.reader(id)
    return function(format)
        local data = socket.read(id, format)
        if data then
            return data
        else
            error(socket_error)
        end
    end
end

function httpsocket.sender(id)
    return function(data)
        local ok = socket.send(id, data)
        if not ok then
            error(socket_error)
        end
    end
end

return httpsocket
