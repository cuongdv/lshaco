local shaco = require "shaco"
local socket = require "socket.c"
local socketbuffer = require "socketbuffer.c"
local socketbuffer_new = assert(socketbuffer.new)
local sformat = string.format
local sunpack = string.unpack
local assert = assert


local connection = {}
local listen_id = false
local maxclient = 0
local client_number = 0

local gateserver = {}

function gateserver.openclient(id)
    local c = connection[id]
    if c then
        socket.readon(id)
    end
end

function gateserver.closeclient(id)
    local c = connection[id]
    if c then
        connection[id] = nil
        socket.close(id)
        client_number = client_number - 1
    end
end

function gateserver.start(handler)
    local handler_connect = assert(handler.connect)
    local handler_disconnect = assert(handler.disconnect)
    local handler_message = assert(handler.message)

    local function disconnect(id, err)
        handler_disconnect(id, err)
        gateserver.closeclient(id)
    end

    local SOCKET = {}

    -- LS_EREAD
    SOCKET[0] = function(id, data, size)
        local c = connection[id]
        if not c then
            shaco.error(sformat('Connection %d drop data size=%d', id, size))
            socket.drop(data, size)
            return
        end
        local function poppack(c)
            if c.head == false then
                local head = c.buffer:pop(2)
                if head == nil then
                    return
                end
                c.head = sunpack('>I2', head)
            end
            local pack = c.buffer:pop(c.head)
            if pack then
                c.head = false
                return pack
            end
        end
        size = c.buffer:push(data, size)
        while true do
            local pack = poppack(c)
            if pack then
                if handler_message(id, pack) then
                    disconnect(id, 'handle msg error')
                    break
                end
            else break
            end
        end
    end

    -- LS_EACCEPT
    SOCKET[1] = function(id)
        if client_number >= maxclient then
            socket.close(id)
            return
        end
        connection[id] = { buffer = socketbuffer_new(), head = false }
        client_number = client_number + 1
        handler_connect(id)
    end

    -- LS_ESOCKERR
    SOCKET[4] = function(id, err)
        local c = connection[id]
        if c then
            connection[id] = nil
            client_number = client_number - 1
            handler_disconnect(id, err)
        end
    end

    shaco.register_protocol {
        id = shaco.TSOCKET,
        name = "socket",
        unpack = socket.unpack,
        dispatch = function(_,_,type, ...)
            local f = SOCKET[type]
            if f then f(...) end
        end,
    }

    local CMD = {}
    
    function CMD.open(conf)
        if listen_id then
            return
        end
        listen_id = assert(socket.listen(conf.address))
        maxclient = conf.maxclient or 1024
    end

    function CMD.close()
        if listen_id then
            socket.close(listen_id)
            listen_id = false
        end
    end

    shaco.start(function()
        shaco.dispatch('lua', function(source, session, cmd, ...)
            local f = CMD[cmd]
            if f then
                shaco.ret(shaco.pack(f(...)))
            else
                shaco.ret(shaoc.pack(handler.command(...)))
            end
        end)
    end)
end

return gateserver
