local shaco = require "shaco"
local c = require "socket.c"
local socketbuffer = require "socketbuffer.c"
local co_running = coroutine.running
local string = string
local assert = assert
local type = type
local tonumber = tonumber

local c_connect = assert(c.connect)
local c_listen = assert(c.listen)
local c_close = assert(c.close)
local c_bind = assert(c.bind)
local c_read = assert(c.read)
local c_send = assert(c.send)
local c_unpack = assert(c.unpack)
local c_readon = assert(c.readon)
local c_readoff = assert(c.readoff)
local socketbuffer_new = assert(socketbuffer.new)

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
event[0] = function(id)
    local s = socket_pool[id] 
    if s then
        local data, n = c_read(id)
        if data then
            n = s.buffer:push(data, n)
            local format = s.read_format
            local rt = type(format)
            -- read by number, or socket.block
            if rt == 'number' then 
                if n >= format then 
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
        elseif n then -- no data, n may is error
            s.connected = false
            s.error = n 
            wakeup(s)
        end
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

local socket = {}

local function alloc(id, callback)
    local s = socket_pool[id]
    assert(not s)
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
function socket.bind(fd)
    local id, err = c_bind(fd)
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

function socket.shutdown(id)
    local s = socket_pool[id]
    if s then
        close(s, false)
    end
end

function socket.close(id)
    local s = socket_pool[id]
    if s then
        close(s, true)
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
        local err = c_send(id, data, i, j)
        if err then
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

return socket
