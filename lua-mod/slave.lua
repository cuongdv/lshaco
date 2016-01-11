local shaco = require "shaco"
local socket = require "socket"

local _harbor_handle
local _slaveid
local _addr
local _master_sock
local _wait
local _connect_queue
local _slaves = {}
local _regs = {}
local _querys = {}

local function pack(...)
    local msg = shaco.packstring(...)
    return string.char(#msg)..msg
end

local function read_package(id)
    local sz  = string.byte(assert(socket.read(id, 1)))
    local msg = assert(socket.read(id, sz))
    return shaco.unpackstring(msg)
end

local function accept_slave(sock)
    socket.start(sock)
    socket.readon(sock)

    local t, slaveid, addr = read_package(sock)
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
    
    _slaves[slaveid] = addr
    shaco.info(string.format('Slave %02x#%s accpet', slaveid, addr))
    return slaveid
end

local function connect_slave(slaveid, addr)
    if _slaves[slaveid] == nil then
        local sock
        local ok, info = pcall(function()
            sock = assert(socket.connect(addr))
            socket.readon(sock)
            assert(socket.send(sock, pack('H', _slaveid, _addr)))
            local t = read_package(sock)
            assert(t=='.', 'handshake fail')

            local p, sz = socket.detachbuffer(sock) 
            p = shaco.topointstring(p)
            socket.abandon(sock)
            shaco.send(_harbor_handle, 'text', 
                string.format('S %d %d %s %s %d', sock, slaveid, addr, p, sz or 0))
            _slaves[slaveid] = addr
            shaco.info(string.format('Slave %02x#%s connect', slaveid, addr))
            end)
        if not ok then 
            socket.close(sock)
            shaco.error(info)
        end
    end
end

local function handle_harbor(_,session, command)
    local t = string.sub(command, 1, 1)
    local args = string.sub(command, 3)
    if t=='D' then
        local slaveid = tonumber(args)
        local slave = _slaves[slaveid]
        if slave then
            _slaves[slaveid] = nil
            shaco.info(string.format('Slave %02x#%s exit', slaveid, slave))
        elseif _wait then
            _wait[slaveid] = nil
        end
    else
        shaco.error("Invalid harbor message type "..t)
    end
end

local master = {}

function master.C(id, addr)
    if _wait then
        _connect_queue[id] = addr
    else
        connect_slave(id, addr)
    end
end

function master.D(id, addr)
    local slave = _slaves[id]
    if slave then
        _slaves[id] = nil
        shaco.info(string.format('Slave %02x#%s exit', id, slave))
    elseif _wait then
        local slave = _connect_queue[id]
        if slave then
            _connect_queue[id] = nil
        else
            _wait[id] = nil
        end
    end
end

function master.N(name, handle)
    assert(type(name)=='string' and type(handle)=='number')
    assert(string.byte(name,1)~=46)
    local slaveid = (handle>>8)&0xff
    assert(slaveid > 0)
    if slaveid ~= _slaveid then
        local q = _querys[name]
        if q then
            _querys[name] = nil
            shaco.call('.service', 'lua', 'REG', '.'..name..' '..handle)
        end
    end
end

local function handle_master(co_main)
    local sock = _master_sock
    while true do
        local ok, t, p1, p2 = pcall(read_package, sock)
        if ok then
            local func = master[t]
            if func then
                local ok, info = pcall(func, p1, p2)
                if not ok then
                    shaco.error(info)
                end
            else
                shaco.error('Invalid master message type '..t)
            end
        else
            shaco.info('Master exit: '..t)
            socket.close(sock)
            break
        end
    end
    _master_sock = nil
    shaco.wakeup(co_main)
end

local harbor = {}

local function send_reg_handle(name, handle)
    socket.send(_master_sock, pack('R', name, handle))
end

local function send_query_handle(name)
    socket.send(_master_sock, pack('Q', name))
end

function harbor.REG(name, handle)
    assert(type(name)=='string' and type(handle)=='number')
    assert(string.byte(name,1)~=46)
    if not _regs[name] then
        _regs[name] = handle
        if not _wait then
            send_reg_handle(name, handle)
        end
    end
end

function harbor.QUERY(name)
    assert(type(name)=='string' and #name > 0)
    assert(string.byte(name,1)~=46)
    local q = _querys[name]
    if q == nil then
        _querys[name] = true
        if not _wait then
            send_query_handle(name)
        end
    end
end

local function handle_command(source, session, cmd, ...)
    local func = harbor[cmd]
    if func then
        func(...)
    else
        shaco.error('Invalid harbor command '..tostring(cmd))
    end
end

local function ready()
    _wait = nil
    local queue = _connect_queue
    _connect_queue = nil
    for k, v in ipairs(queue) do
        connect_slave(k, v)
    end
    for name, handle in pairs(_regs) do
        send_reg_handle(name, handle)
    end
    for name, v in pairs(_querys) do
        send_query_handle(name)
    end
end

local function connect_master()
    local sock
    local ok, info = pcall(function()
        local addr = assert(shaco.getenv('master'))
        shaco.info(string.format('Slave %02x connect to master %s', 
            _slaveid, addr))
        sock = assert(socket.connect(addr))
        socket.readon(sock)
        assert(socket.send(sock, pack('H', _slaveid, _addr)))
        _wait = {}
        local t, n = read_package(sock)
        assert(t=='W' and type(n)=='number', 'Handshake fail')
        if n > 0 then
            for i=1,n do
                local t, slaveid, addr = read_package(sock)
                assert(t=='S' and 
                    type(slaveid)=='number' and 
                    type(addr)=='string', 'Handshake fail')
                if _slaves[slaveid] == nil then
                    _wait[slaveid] = addr
                end
            end
        end
    end)
    if not ok then
        shaco.error(info)
        socket.close(sock)
    else return sock
    end
end

local function listen()
    local sock
    local ok, info = pcall(function()
        shaco.info(string.format('Slave %02x listen on %s',
            _slaveid, _addr))
        sock = assert(
        socket.listen(_addr, function(id)
            local ok, info = pcall(accept_slave, id)
            if not ok then
                shaco.error(info)
                socket.close(id)
            else
                _wait[info] = nil
            end
        end))
    end)
    if not ok then
        shaco.error(info)
    else return sock
    end
end

local function waiting_slaves(sock, co_main)
    local n = 0
    for k, v in pairs(_wait) do
        n = n + 1
    end
    if n == 0 then
        return
    end
    shaco.fork(function(co_main)
        while _wait do
            local n = 0
            for k,v in pairs(_wait) do
                n = n+1
            end
            if n == 0 then
                break
            end
            shaco.sleep(10)
        end
        if _master_sock then
            shaco.wakeup(co_main)
        -- or co_main is wakeup by handle_master
        end
    end, co_main)
    shaco.wait()
end

shaco.start(function()
    _harbor_handle = assert(tonumber(shaco.command('LAUNCH', 'harbor '..shaco.handle())))
    _slaveid = assert(tonumber(shaco.getenv('slaveid')))
    _addr = assert(shaco.getenv('address'))

    shaco.dispatch('lua',  handle_command)
    shaco.dispatch('text', handle_harbor)

    shaco.fork(function()
        while true do
            _wait = nil
            _connect_queue = {}
            local slave_sock = listen()
            if slave_sock then
                _master_sock = connect_master()
                if _master_sock then
                    local co_main = coroutine.running()
                    shaco.fork(handle_master, co_main)
                    waiting_slaves(slave_sock, co_main)
                    socket.close(slave_sock)
                    if _master_sock then
                        shaco.info('Handshake ok')
                        shaco.fork(ready)
                        shaco.wait()
                    else
                        shaco.error('Handshake break by master exit')
                    end
                else
                    socket.close(slave_sock)
                end
            end
            shaco.sleep(3000)
        end
    end)
end)
