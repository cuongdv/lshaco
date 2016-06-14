local shaco = require "shaco"
local c = require "socket.c"
local socketbuffer = require "socketbuffer.c"
local co_running = coroutine.running
local sformat = string.format
local sunpack = string.unpack
local assert = assert
local type = type
local tonumber = tonumber

local socket = {}

local __error = setmetatable({}, { __tostring = function() return "[Error: socket]" end })

local c_connect = assert(c.connect)
local c_listen = assert(c.listen)
local c_close = assert(c.close)
local c_bind = assert(c.bind)
local c_send = assert(c.send)
local c_sendfd = assert(c.sendfd)
local c_unpack = assert(c.unpack)
local c_readon = assert(c.readon)
local c_readoff = assert(c.readoff)
local c_drop = assert(c.drop)
local socketbuffer_new = assert(socketbuffer.new)
socket.getfd = assert(c.getfd)
socket.pair = assert(c.pair)
socket.closefd = assert(c.closefd)
socket.error = assert(__error)

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
        if s.connected then
            c_close(id, force)
            s.connected = false
        end
        if s.co then
            wakeup(s)
        else
            socket_pool[id] = nil
        end
    end
end

local event = {}

-- SOCKET_TYPE_READ
event[0] = function(id, data, size)
    local s = socket_pool[id] 
    if s == nil then
        shaco.error(sformat('Socket %d drop data size=%d', id, size))
        c_drop(data, size)
        return
    end
    size = s.buffer:push(data, size)
    if s.rlimit and size > s.rlimit then
        shaco.error(sformat('Socket %d read buffer too large %d', id, size))
        c_close(id, true)
        s.connected = false
        s.buffer:clear() -- clear or read will call buffer pop
        wakeup(s)
        return
    end
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

-- SOCKET_TYPE_ACCEPT
event[1] = function(id, listenid, addr) 
    local listen_s = socket_pool[listenid] 
    listen_s.callback(id, addr)
end

-- SOCKET_TYPE_CONNECT
event[2] = function(id)
    local s = socket_pool[id]
    if s then
        s.connected = true
        wakeup(s)
    end
end

-- SOCKET_TYPE_CONNERR
event[3] = function(id)
    local s = socket_pool[id]
    if s then
        s.connected = false
        wakeup(s) 
    end
end

-- SOCKET_TYPE_SOCKERR
event[4] = function(id)
    local s = socket_pool[id]
    if s then
        s.connected = false
        wakeup(s)
    end
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
    assert(s == nil, id)
    s = { 
        id = id,
        connected = false,
        co = false,
        buffer = false,
        read_format = false,
        callback = callback,
        rlimit = nil,
        slimit = nil,
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
    if s then socket_pool[id] = nil end
end

-- return the remain buffer data (p, sz)
function socket.detachbuffer(id)
    local s = socket_pool[id]
    if s and s.buffer then
        return s.buffer:detach()
    end
end

function socket.listen(addr, callback)
    local id = c_listen(addr)
    if id then
        local s = alloc(id, callback)
        s.connected = true
    end
    return id
end

function socket.connect(...)
    local id, conning = c_connect(...)
    if id then
        local s = alloc(id)
        if conning then 
            suspend(s)
            if s.connected then
                return s.id
            else
                socket_pool[id] = nil
                return nil
            end
        end
        return id
    else 
        return nil
    end
end

-- wrap a exist fd to socket
function socket.bind(fd, protocol)
    if protocol == 'IPC' then
        protocol = 2 -- see socket.h
    else protocol = nil
    end
    local id = c_bind(fd, protocol)
    if id then
        local s = alloc(id)
        s.connected = true
    end
    return id
end

function socket.stdin()
    local id = socket.bind(0)
    if id then
        socket.readon(id)
    end
    return id
end

function socket.close(id, force)
    if force ==nil then
        force = true
    end
    --force = force or true
    local s = socket_pool[id]
    if s then 
        close(s, force) 
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
    return s.connected
end

function socket.read(id, format)
    local s = socket_pool[id]
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
        return nil, __error
    end
end

function socket.send(id, data, i, j)
    local s = socket_pool[id]
    if s.connected then
        local size = c_send(id, data, i, j)
        if size then
            if s.slimit and size > s.slimit then
                shaco.error(sformat('Socket %d send buffer too large %d', id, size))
                c_close(id)
                socket_pool[id] = nil
            else return true end
        else
            socket_pool[id] = nil
        end
    end
    -- do not clear socket when connected is false,
    -- do this only when reading
    -- socket_pool[id] = nil
    return nil, __error
end

function socket.ipc_read(id, format)
    return socket.read(id, format)
end

function socket.ipc_readfd(id, format)
    local fd
    if format == nil then
        fd = socket.read(id, 5) -- send fd only with one byte empty data
        if fd then
            fd = sunpack('=i', fd)
            return fd
        end
    else
        fd = socket.read(id, 4)
        if fd then
            data = socket.read(id, format)
            if data then
                fd = sunpack('=i', fd)
                return fd, data
            end
        end
    end
    return nil, __error
end

function socket.ipc_sendfd(id, fd, ...)
    local s = socket_pool[id]
    if s.connected then
        local size = c_sendfd(id, fd, ...)
        if size then
            return true
        else
            socket_pool[id] = nil
        end
    end
    -- do not clear socket when connected is false,
    -- do this only when reading
    -- socket_pool[id] = nil
    return nil, __error
end

function socket.ipc_send(id, data, i, j)
    local s = socket_pool[id]
    if s.connected then
        local size = c_sendfd(id, nil, data, i, j)
        if size then
            return true
        else
            socket_pool[id] = nil
        end
    end
    -- do not clear socket when connected is false,
    -- do this only when reading
    -- socket_pool[id] = nil
    return nil, __error
end

function socket.limit(id, rlimit, slimit)
    local s = socket_pool[id]
    s.rlimit = rlimit
    s.slimit = slimit
end

function socket.reinit()
    for id, s in pairs(socket_pool) do
        close(s, true)
    end
    c.reinit()
end

return socket
