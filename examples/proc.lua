local shaco = require "shaco"
local socket = require "socket"
local socketchannel = require "socketchannel"
local process = require "process.c"
local signal = require "signal.c"
local sformat = string.format

local _nworker = tonumber(...) or 1
local _workers = {}

local function run_client(id)
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

local function run_worker(channel)
    while true do
        local ok, err = pcall(function()
            local fd = channel.readfd()
            local id = assert(socket.bind(fd))
            shaco.fork(function()
                local ok, err = pcall(run_client, id, fd)
                socket.close(id)
                if not ok then
                    shaco.error(sformat('Client %d error: %s', id, err))
                    channel.send('error\n')
                else
                    shaco.trace(sformat('Client %d closed', id))
                    channel.send('ok\n')
                end
            end)
        end)
        if not ok then
            shaco.error(err)
            os.exit(1) -- fatal error just exit
        end
    end
end

local function worker_channel(fd)
    local channel = assert(socket.bind(fd, 'IPC'))
    socket.readon(channel)
    -- channel error, just exit
    local function readfd()
        local fd, err = socket.ipc_readfd(channel)
        if not fd then
            shaco.error('Channel readfd error: '..err)
            os.exit(1)
        end
        return fd
    end
    local function send(command)
        local ok, err = socket.ipc_send(channel, command)
        if not ok then
            shaco.error('Channel send error: '..err)
            os.exit(1)
        end
    end
    return { 
        readfd = readfd, 
        send = send 
    }
end

local function master_channel(fd)
    local id, err = socket.bind(fd, 'IPC')
    if not id then
        socket.closefd(fd)
        error(err)
    end
    socket.readon(id)
    local channel, err = socketchannel.create{id=id}
    if not channel then
        socket.close(id)
        error(err)
    end
    return channel
end

local function fork_worker(index)
    local fd0, fd1, pid
    local ok, err = pcall(function()
        local err
        fd0, fd1 = assert(socket.pair())
        pid, err = process.fork()
        if not pid then
            socket.closefd(fd0)
            socket.closefd(fd1)
            error(err)
        end
    end)
    if not ok then
        shaco.error('Master fork error:'..err)
        return
    end
    if pid == 0 then
        local ok, err = pcall(function()
            socket.closefd(fd0)
            process.settitle('worker process')
            process.stdnull(1,0,0)
            shaco.kill('console')
            for i=1, #_workers do
                local w = _workers[i]
                if w.channel then
                    w.channel:close()
                end
            end
            _workers = nil
            socket.reinit()
            local channel = worker_channel(fd1)
            shaco.fork(run_worker, channel)
            shaco.info(sformat('Worker [%d:%d] start', index, process.getpid()))
        end)
        if not ok then
            shaco.error(sformat('Worker start error: %s', err))
            os.exit(1)
        end
        return 'child'
    else
        local ok, w = pcall(function()
            socket.closefd(fd1)
            process.settitle('master process')
            return {
                index = index,
                pid = pid,
                channel = master_channel(fd0),
                status = 'ok',
            }
        end)
        if not ok then
            shaco.error('Master channel error: '..w)
        else return w
        end
    end
end

local function prefork_workers()
    for i=1, _nworker do
        local w = _workers[i]
        if not w or not w.pid then
            local w = fork_worker(i)
            if w then
                if w=='child' then 
                    return 'child'
                end
                _workers[i] = w
            else break
            end
        end
    end
end

local function balance()
    local index = 0
    return function()
        for i=1, #_workers do
            index = index + 1
            if index > #_workers then
                index = 1
            end
            local slave = _workers[index]
            if slave.channel then
                return slave
            end
        end
    end
end

local function start_listen(addr)
    local next_slave = balance()
    local listen_sock = assert(socket.listen(
        addr, function(id)
            local ok, err = pcall(function()
                local client_fd = socket.getfd(id)
                shaco.trace(sformat('Sock %d, fd=%d accept', id, client_fd))
                local slave = next_slave()
                if not slave then
                    error('Worker none')
                end
                shaco.trace(sformat("Worker [%d:%d] selected", 
                    slave.index, slave.pid))
                local channel = slave.channel
                local data, err = channel:request(
                    function(id) return assert(socket.ipc_sendfd(id, client_fd)) end,
                    function(id) return assert(socket.ipc_read(id, '\n')) end)
                if not data then
                    channel:close()
                    slave.channel = false
                    slave.status  = 'disconnect'
                    error(err)
                end
                shaco.trace(sformat("Worker [%d:%d] return %s", 
                    slave.index, slave.pid, data))
                shaco.sleep(1000)
            end)
            shaco.trace(sformat('Sock %d closed', id))
            socket.close(id)
            if not ok then
                shaco.error(err)
            end
        end))
    shaco.info('listen on '..addr)
end

shaco.start(function()
    signal.signal(signal.SIGCHLD, function(sig, pid, reason, code, extra)
        shaco.error(sformat('Worker [%d] exit due %s(%d) %s', pid, reason, code, extra))
        for _, w in ipairs(_workers) do
            if w.pid == pid then
                w.pid = false
                w.channel:close()
                w.channel = false
                w.status = 'exited'
            end
        end
    end)
    start_listen('127.0.0.1:1234')
    if prefork_workers() ~= 'child' then
        shaco.fork(function()
            while true do
                if prefork_workers() ~= 'child' then
                    shaco.sleep(1000)
                else break
                end
            end
        end)
    end
end)
