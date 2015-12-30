local shaco = require "shaco"
local c = require "socket.c"
local socketbuffer = require "socketbuffer.c"
local co_running = coroutine.running
local string = string
local strunpack = string.unpack
local assert = assert
local type = type
local tonumber = tonumber

local socket = {}

local c_connect = assert(c.connect)
local c_listen = assert(c.listen)
local c_close = assert(c.close)
local c_bind = assert(c.bind)
--local c_read = assert(c.read)
local c_send = assert(c.send)
local c_sendfd = assert(c.sendfd)
--local c_readfd = assert(c.readfd)
local c_unpack = assert(c.unpack)
local c_readon = assert(c.readon)
local c_readoff = assert(c.readoff)
local c_drop = assert(c.drop)
local socketbuffer_new = assert(socketbuffer.new)
socket.getfd = assert(c.getfd)
socket.pair = assert(c.pair)

local socket_pool = {}

local function suspend(s)
    assert(not s.co)
    s.co = co_running()
    shaco.wait()
end

local function wakeup(s)
    local co = s.co
    if co then
        s.co = nil
        shaco.wakeup(co)
    end
end

local function close(s, force)
    if s then
        local id = s.id
        socket_pool[id] = nil
        if s.connected then
            c_close(id, force)
        end
    end
end

local event = {}

-- LS_EREAD
event[0] = function(id, data, size)
    local s = socket_pool[id] 
    if s == nil then
        shaco.error(string.format('Socket %d drop data size=%d', id, size))
        c_drop(data, size)
        return
    end
    size = s.buffer:push(data, size)
    local format = s.read_format
    local rt = type(format)
    -- read by number, or socket.block
    if rt == 'number' then 
        if size >= format then 
            wakeup(s)
        end
    -- read by separator
    elseif rt == 'string' then
        if s.buffer:findsep(format) then
            wakeup(s)
        end
    else -- read all
        wakeup(s)
    end
end

-- LS_EACCEPT
event[1] = function(id, listenid) 
    local listen_s = socket_pool[listenid] 
    listen_s.callback(id)
end

-- LS_ECONNECT
event[2] = function(id)
    local s = socket_pool[id]
    if not s then
        return
    end
    s.connected = true
    wakeup(s)
end

-- LS_ECONNERR
event[3] = function(id, err)
    local s = socket_pool[id]
    if not s then
        return
    end
    s.connected = false
    s.error = err
    wakeup(s) 
end

-- LS_ESOCKERR
event[4] = function(id, err)
    local s = socket_pool[id]
    if not s then
        return
    end
    s.connected = false
    s.error = err
    wakeup(s)
end

shaco.register_protocol {
    id = shaco.TSOCKET,
    name = "socket",
    unpack = c_unpack,
    dispatch = function(_,_,type, ...)
        local f = event[type]
        if f then f(...) end
    end,
}

local function alloc(id, callback)
    local s = socket_pool[id]
    assert(not s, 'id existed '..id)
    s = { 
        id = id,
        connected = false,
        co = false,
        buffer = false,
        read_format = false,
        callback = callback,
        error = "none",
    }
    socket_pool[id] = s
    return s
end

function socket.start(id)
    local s = alloc(id)
    s.connected = true
end

function socket.abandon(id)
    local s = socket_pool[id]
    if s then
        socket_pool[id] = nil
    end
end

-- return the remain buffer data (p, sz)
function socket.detachbuffer(id)
    local s = socket_pool[id]
    if s and s.buffer then
        return s.buffer:detach()
    end
end

function socket.listen(ip, port, callback)
    if type(port) == 'function' then
        callback = port
        ip, port = string.match(ip, '([^:]+):(%d+)$')
        port = tonumber(port)
    else
        assert(type(callback)=='function')
    end
    local id, err = c_listen(ip, port)
    if id then
        local s = alloc(id, callback)
        s.connected = true
        return id
    else 
        return id, err
    end
end

function socket.connect(ip, port)
    if port == nil then
        ip, port = string.match(ip, '([^:]+):(%d+)$')
        port = tonumber(port)
    end
    local id, conning = c_connect(ip, port)
    if id then
        local s = alloc(id)
        if conning then 
            suspend(s)
            if s.connected then
                return s.id
            else
                socket_pool[id] = nil
                return nil, s.error
            end
        else return id end
    else 
        return nil, conning -- error
    end
end

-- wrap a exist fd to socket
function socket.bind(fd, protocol)
    if protocol == 'IPC' then
        protocol = 2 -- see socket_define.h
    else protocol = nil
    end
    local id, err = c_bind(fd, protocol)
    if id then
        local s = alloc(id)
        s.connected = true
        return id
    else 
        return nil, err
    end
end

function socket.stdin()
    local id, err = socket.bind(0)
    if id then
        socket.readon(id)
        return id
    else
        return nil, err
    end
end

--function socket.shutdown(id)
--    local s = socket_pool[id]
--    if s then
--        close(s, false)
--    end
--end

function socket.close(id, force)
    force = force or true
    local s = socket_pool[id]
    if s then
        close(s, force)
    else
        c_close(id, force)
    end
end

function socket.readon(id)
    local s = socket_pool[id]
    assert(s) 
    c_readon(id)
    if not s.buffer then 
        s.buffer = socketbuffer_new()
    end
end

function socket.readoff(id)
    local s = socket_pool[id]
    assert(s) 
    c_readoff(id)
end

function socket.block(id)
    local s = socket_pool[id]
    assert(s)
    s.read_format = 0
    suspend(s)
    return s.connected, s.error
end

function socket.read(id, format)
    local s = socket_pool[id]
    assert(s)
    format = format or false
    s.read_format = format
    local data = s.buffer:pop(format)
    if data then
        return data
    else -- check connected first 
        if s.connected then 
            suspend(s)
            if s.connected then
                return s.buffer:pop(format)
            end
        end
        socket_pool[id] = nil
        return nil, s.error
    end
end

function socket.send(id, data, i, j)
    local s = socket_pool[id]
    assert(s)
    if s.connected then
        local ok, err = c_send(id, data, i, j)
        if not ok then
            socket_pool[id] = nil
            return nil, err
        else return true 
        end
    else
        -- do not clear socket when connected is false,
        -- do this only when reading
        -- socket_pool[id] = nil
        return nil, s.error
    end
end

function socket.ipc_read(id, format)
    return socket.read(id, format)
end

function socket.ipc_readfd(id, format)
    local fd, err
    if format == nil then
        fd, err = socket.read(id, 5) -- send fd only with one byte empty data
        if fd then
            fd = strunpack('=i', fd)
            return fd
        end
    else
        fd, err = socket.read(id, 4)
        if fd then
            data, err = socket.read(id, format)
            if data then
                fd = strunpack('=i', fd)
                return fd, data
            end
        end
    end
    return nil, err
end

function socket.ipc_sendfd(id, fd, ...)
    local s = socket_pool[id]
    assert(s)
    if s.connected then
        local ok, err = c_sendfd(id, fd, ...)
        if not ok then
            socket_pool[id] = nil
            return nil, err
        else return true 
        end
    else
        -- do not clear socket when connected is false,
        -- do this only when reading
        -- socket_pool[id] = nil
        return nil, s.error
    end
end

function socket.ipc_send(id, data)
    local s = socket_pool[id]
    assert(s)
    if s.connected then
        local ok, err = c_sendfd(id, nil, data)
        if not ok then
            socket_pool[id] = nil
            return nil, err
        else return true 
        end
    else
        -- do not clear socket when connected is false,
        -- do this only when reading
        -- socket_pool[id] = nil
        return nil, s.error
    end

end

function socket.reinit()
    for id, s in pairs(socket_pool) do
        close(s, true)
    end
    c.reinit()
end

return socket
