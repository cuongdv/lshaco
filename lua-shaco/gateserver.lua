local shaco = require "shaco"
local socket = require "socket.c"
local socketbuffer = require "socketbuffer.c"
local socketbuffer_new = assert(socketbuffer.new)
local sformat = string.format
local sunpack = string.unpack
local assert = assert


local connection = {}
local listen_id = false
local rlimit
local slimit
local maxclient = 0
local client_number = 0
local gateserver = {}

local handle_reject
local disconnect

function gateserver.openclient(id)
    if connection[id] then
        socket.readon(id)
    end
end

function gateserver.closeclient(id)
    disconnect(id, true)
end

function gateserver.send(id, data)
    if connection[id] then
        local size = socket.send(id, data)
        if size then
            if slimit and size > slimit then
                shaco.error(sformat('Connection %d send buffer too large %d', id, size))
                disconnect(id, true, "sendbuffer")
            end
        else disconnect(id, false, "socket")
        end
    end
end

function gateserver.start(handle)
    local handle_connect = assert(handle.connect)
    local handle_disconnect = assert(handle.disconnect)
    local handle_message = assert(handle.message)
    local handle_reject = handle.reject
    local handle_command = handle.command

    -- local
    function disconnect(id, close, err) 
        if connection[id] then
            connection[id] = nil
            if close then
                socket.close(id)
            end
            client_number = client_number - 1
            handle_disconnect(id, err)
        end
    end

    local SOCKET = {}

    -- SOCKET_TYPE_READ
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
                --c.head = sunpack('>I2', head)
                c.head = sunpack('<I2', head)
            end
            local pack = c.buffer:pop(c.head)
            if pack then
                c.head = false
                return pack
            end
        end
        size = c.buffer:push(data, size)
        if rlimit and size > rlimit then
            shaco.error(sformat('Connection %d read buffer too large %d', id, size))
            disconnect(id, true, "readbuffer")
            return
        end
        while true do
            local pack = poppack(c)
            if pack then
                if handle_message(id, pack) then
                    disconnect(id, true, "message")
                    break
                end
            else break end
        end
    end

    -- SOCKET_TYPE_ACCEPT
    SOCKET[1] = function(id, listenid, addr)
        if client_number >= maxclient then
            if handle_reject then
                handle_reject(id, addr)
            end
            socket.close(id)
            return
        end
        connection[id] = { buffer = socketbuffer_new(), head = false }
        client_number = client_number + 1
        handle_connect(id, addr)
    end

    -- SOCKET_TYPE_SOCKERR
    SOCKET[4] = function(id)
        disconnect(id, false, "socket")
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
        assert(listen_id == false)
        shaco.info('Listen on ' ..conf.address)
        listen_id = assert(socket.listen(conf.address))
        maxclient = conf.maxclient or 1024
        rlimit = conf.rlimit
        slimit = conf.slimit
        if handle.open then
            handle.open(conf)
        end
    end

    function CMD.close()
        if listen_id then
            socket.close(listen_id)
            listen_id = false
        end
    end

    shaco.start(function()
        if handle.init then
            handle.init()
        end
        shaco.dispatch('lua', function(source, session, cmd, ...)
            local f = CMD[cmd]
            if f then
                shaco.ret(shaco.pack(f(...)))
            else
                shaco.ret(shaco.pack(handle_command(cmd, ...)))
            end
        end)
    end)
end

return gateserver
