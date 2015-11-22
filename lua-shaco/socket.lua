local shaco = require "shaco"
local c = require "socket.c"
local socketbuffer = require "socketbuffer.c"
local coroutine = coroutine

local socket_pool = {}

local function suspend(s)
    assert(s.co == coroutine.running())
    coroutine.yield() 
    local data = s.__data
    local err = s.__error
    s.__data = nil
    s.__error = nil
    return data, err
end

local function disconnect(id, force, err)
    local s = socket_pool[id]
    if s then
        assert(s.id == id)
        c.close(id, force)
        socket_pool[id] = nil
    end
end

local event = {}

-- LS_EREAD
event[0] = function(id)
    local s = socket_pool[id] 
    if s == nil then return end
    local data, n = c.read(id)
    if data then
        s.buffer:push(data, n)
        if s.mode then
            local data = s.buffer:pop(s.mode)
            if data then
                s.__data = data
                shaco.wakeup(s.co)
            end
        else -- see socket.block
            s.__data = true
            shaco.wakeup(s.co)
        end
    elseif n then
        local co = s.co
        disconnect(id, true, n)
        s.__error = c.error(n)
        shaco.wakeup(co)
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
    assert(s.id == id)
    s.__data = s.id
    shaco.wakeup(s.co, s.id)
end

-- LS_ECONNERR
event[3] = function(id, err)
    local s = socket_pool[id]
    assert(s.id == id)
    disconnect(id, true, err)
    s.__error = c.error(err)
    shaco.wakeup(s.co) 
end

-- LS_ESOCKERR
event[4] = function(id, err)
    local s = socket_pool[id]
    assert(s.id == id)
    disconnect(c, true, err)
    self.__error = c.error(err)
    shaco.wakeup(s.co)
end

shaco.register_protocol {
    id = shaco.TSOCKET,
    name = "socket",
    unpack = c.unpack,
    dispatch = function(_,_,type, ...)
        local f = event[type]
        if f then f(...) end
    end,
}

local socket = {}

function socket.listen(ip, port)
    return c.listen(ip, port)
end

function socket.connect(ip, port)
    local id, err, conning = c.connect(ip, port)
    if id then
        socket.start(id)
        if conning then
            local s = socket_pool[id]
            return suspend(s)
        else return id end
    else return nil, c.error(err)
    end
end

function socket.start(id, callback)
    assert(socket_pool[id] == nil)
    socket_pool[id] = { 
        id = id,
        co = coroutine.running(),
        buffer = nil,
        mode = "*l",
        callback = callback,
    }
end

function socket.bind(id, co)
    local s = socket_pool[id]
    assert(s)
    s.co = co
end

function socket.block(id)
    local s = socket_pool[id]
    assert(s)
    s.co = coroutine.running()
    s.mode = nil
    return suspend(s)
end

function socket.shutdown(id)
    disconnect(id, false, 0)
end

function socket.close(id)
    disconnect(id, true, 0)
end

function socket.readenable(id, enable)
    local s = socket_pool[id]
    assert(s) 
    c.readenable(id, enable)
    if enable and not s.buffer then     
        s.buffer = socketbuffer.new()
    end
end

function socket.read(id, mode)
    assert(mode)
    local s = socket_pool[id]
    assert(s)
    assert(s.id == id)
    s.mode = mode
    local data = s.buffer:pop(mode)
    if data then
        return data
    else
        return suspend(s)
    end
end

function socket.send(id, data, i, j)
    local err = c.send(id, data, i, j)
    if err then
        disconnect(id, true, err)
        return nil, c.error(err)
    else return true end
end

return socket
