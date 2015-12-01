local shaco = require "shaco"
local socket = require "socket"

local _harbor_handle
local _slaveid
local _addr
local _slaves = {}
local _connect_queue = {}

local function pack(...)
    local msg = shaco.packstring(...)
    return string.char(#msg)..msg
end

local function read_pack(id)
    local sz = assert(socket.read(id, '*1'))
    local msg = assert(socket.read(id, sz))
    return shaco.unpackstring(msg)
end

local function accept_slave(sock)
    socket.start(sock)
    socket.readenable(sock, true)

    local t, slaveid, addr = read_pack(sock)
    assert(t=='H' and 
        type(slaveid)=='number' and 
        type(addr)=='string', 'Handshake fail')
    if _slaves[slaveid] then
        error(string.format('Slave %02x already exist',slaveid))
    end
    
    --local tt = pack('.')
    --local tt2 = string.pack('>I4I2I1I1I4c6',13,3,5,1,0,"T 1234")
    --socket.send(sock, tt..tt2)
    socket.send(sock, pack('.'))

    --readbuffer must be empty, due to the other side wait '.'
    --so the under line is unness
    local p, sz = socket.detachbuffer(sock)
    p = shaco.topointstring(p)
    socket.abandon(sock)
    shaco.send(_harbor_handle, 'text',
        string.format('S %d %d %s %s %d', sock, slaveid, addr, p, sz or 0))

    _slaves[slaveid] = { id=slaveid, sock=sock, addr=addr }
    shaco.info(string.format('Slave %02x#%s accpet', slaveid, addr))
end

local function connect_slave(slaveid, addr)
    local sock = assert(socket.connect(addr))
    socket.readenable(sock, true)
    socket.send(sock, pack('H', _slaveid, _addr))
    local t = read_pack(sock)
    assert(t=='.', 'handshake fail')

    local p, sz = socket.detachbuffer(sock) 
    p = shaco.topointstring(p)
    socket.abandon(sock)
    shaco.send(_harbor_handle, 'text', 
        string.format('S %d %d %s %s %d', sock, slaveid, addr, p, sz or 0))

    _slaves[slaveid] = {id=slaveid, sock=sock, addr=addr }
    shaco.info(string.format('Slave %02x#%s connect', slaveid, addr))
end

local function monitor_master(master_sock)
    socket.start(master_sock)
    while true do
        local ok, t, id_name, addr = pcall(read_pack, master_sock)
        if ok then
            if t=='C' then
                if _connect_queue then
                    _connect_queue[id_name] = addr
                else
                    connect_slave(id_name, addr)
                end
            elseif t=='D' then
                local slave = _slaves[id_name]
                if slave then
                    _slaves[id_name] = nil
                    socket.close(slave.sock)
                end
            else
                shaco.error('Invalid master message type '..t)
            end
        else
            shaco.info(t)
            -- todo master disconnect
            socket.close(master_sock)
            break
        end
    end
end

local function ready()
    local queue = _connect_queue
    _connect_queue = nil
    for k, v in ipairs(queue) do
        connect_slave(k, v)
    end
end

shaco.start(function()
    _harbor_handle = assert(shaco.launch('harbor'))

    _slaveid = assert(tonumber(shaco.getenv('slaveid')))
    _addr = assert(shaco.getenv('address'))
    local master_addr  = assert(shaco.getenv('master'))
    local slave_sock = assert(socket.listen(_addr))
    --shaco.dispatch('lua', function(source, session, cmd, ...)
    --end)
    shaco.info(string.format('Slave %02x connect to master %s', _slaveid, master_addr))
    local master_sock = assert(socket.connect(master_addr))
    socket.readenable(master_sock, true)
    assert(socket.send(master_sock, pack('H', _slaveid, _addr)))
    local t, n = read_pack(master_sock)
    assert(t=='W' and type(n)=="number", 'Handshake fail')
    shaco.info(string.format('Waiting for %d slaves', n))
    shaco.fork(monitor_master, master_sock)
    if n > 0 then
        local co = coroutine.running()
        socket.start(slave_sock, function(id)
            shaco.fork(function()
                local ok, info = pcall(accept_slave, id)
                if ok then
                    local s = 0
                    for k,v in pairs(_slaves) do
                        s = s + 1
                    end
                    if s == n then
                        shaco.wakeup(co)
                    end
                else
                    shaco.error(info)
                    socket.close(id)
                end
            end)
        end)
        shaco.wait()
    end
    socket.close(slave_sock)
    shaco.info('Handshake ok')
    shaco.fork(ready)
end)
