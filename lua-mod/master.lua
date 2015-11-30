--[[
    slave -> master:
    'H': Handshake, report slave handle, slave id, slave address

    master -> slave:
    'W': Wait n slave
]]

local shaco = require "shaco"
local socket = require "socket"

local _slaves = {}
local _global_names = {}

local function pack(...)
    local msg = shaco.packtostring(...)
    return string.pack('>Hz', #msg, msg)
end

local function read_pack(id)
    local sz  = assert(socket.read(id, '*2'))
    local msg = assert(socket.read(id, sz))
    return shaco.unpack(msg)
end

local function dispatch_slave(sock)
    local t, name, handle = read_pack(sock)
    if t=='R' then
        if not _global_names[name] then
            _global_names[name] = handle
        end
        local msg = pack('N', name, handle)
        for k, v in pairs(_slaves) do
            if v.sock ~= sock then
                socket.send(v.sock, msg)
            end
        end
    elseif t=='Q' then
        local handle = _global_names[name]
        if handle then
            assert(socket.send(sock, pack('N', name, handle)))
        end
    else
        shaco.error('Invalid slave message type '..t)
    end
end

local function monitor_slave(slaveid)
    local slave = _slaves[slaveid]
    local sock  = slave.sock
    while pcall(dispatch_slave, sock) do end
    socket.close(sock)
    _slaves[slaveid] = nil
    for k, v in pairs(_slaves) do
        send(v.sock, 'D', slaveid)
    end
    shaco.info(string.format('Slave %d#%s exit', slaveid, slave.addr))
end

local function accept_salve(sock)
    socket.start(sock)
    socket.readenable(sock, true)

    local t, slaveid, addr = read_pack(sock)
    assert(t=='H' and
        type(slaveid)=='number' and
        type(addr)=='string', 'Handshake fail')
    if _slaves[slaveid] then
        error(string.format('Slave %d already register on %s', slaveid, addr))
    end

    local n = 0
    for k, v in pairs(_slaves) do
        send(slave.sock, 'C', v.id, v.addr)
        n = n + 1
    end
    assert(socket.send(sock, pack('W', s)))

    _slaves[slaveid] = {id=slaveid, sock=sock, addr = addr}
    shaco.info(string.format('Slave %d#%s register', slaveid, addr))
    return 'ok', slaveid
end

shaco.start(function()
    local addr = assert(shaco.getenv('standalone'))
    shaco.info('Master listen on '..addr)
    local sock = assert(socket.listen(addr))
    socket.start(sock, function(id)
        shaco.fork(function()
            local ok, info, slaveid = pcall(accept_slave, id)
            if ok then
                shaco.fork(monitor_slave, slaveid)
            else
                shaco.error(info)
                socket.close(id)
            end
        end)
    end)
end
