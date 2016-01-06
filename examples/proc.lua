local shaco = require "shaco"
local socket = require "socket"
local mworker = require "mworker"
local sformat = string.format

local server = {
    address = "127.0.0.1:1234",
    worker = 1,
}

function server.worker_handler(id)
    shaco.trace(sformat('Client %d comein', id))
    socket.readon(id)
    while true do
        local s = assert(socket.read(id, '\n'))
        shaco.trace(sformat('Client %d read %s', id, s))
        if s == 'exit' then
            break
        end
        socket.send(id, s..'\n')
    end
end

function server.master_handler(id, worker, ...)
    shaco.trace(sformat("Worker %s return ", worker), ...)
    shaco.sleep(1000)
end

mworker(server)
