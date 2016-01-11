local shaco = require "shaco"
local socket = require "socket"
local socketchannel = require "socketchannel"
local process = require "process.c"
local signal = require "signal.c" 
local sformat = string.format
local spack = string.pack
local sunpack = string.unpack

local _workers = {}

local function run_worker(channel, handler)
    while true do
        local ok, err = pcall(function()
            local fd = channel.readfd()
            local id = assert(socket.bind(fd))
            shaco.fork(function()
                local function response(id, ok, err, ...)
                    socket.close(id)
                    local ret
                    if ok then
                        ret = shaco.packstring(err, ...)
                    else
                        ret = shaco.packstring(false)
                        shaco.error(err)
                    end
                    channel.send(spack('s2', ret))
                end
                response(id, pcall(handler, id))
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
    local function send(...)
        local ok, err = socket.ipc_send(channel, ...)
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

local function fork_worker(conf, index)
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
            shaco.command('SETENV', 'isworker 1')
            if conf.worker_init then
                conf.worker_init()
            end
            local channel = worker_channel(fd1)
            shaco.fork(run_worker, channel, conf.worker_handler)
            shaco.info(sformat('Worker %d:%d start', index, process.getpid()))
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
                name = tostring(index)..':'..pid,
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

local function prefork_workers(conf)
    for i=1, conf.worker do
        local w = _workers[i]
        if not w or not w.pid then
            local w = fork_worker(conf, i)
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

local function start_listen(conf)
    local listen_addr = conf.address
    local master_handler = conf.master_handler
    local next_slave = balance()
    shaco.info('Listen on '..listen_addr)
    local listen_sock = assert(socket.listen(
        listen_addr, function(id)
            local ok, err = pcall(function()
                local client_fd = socket.getfd(id)
                shaco.trace(sformat('Sock %d, fd=%d accept', id, client_fd))
                local slave = next_slave()
                if not slave then
                    error('Worker none')
                end
                shaco.trace(sformat("Worker %s selected", slave.name))
                local channel = slave.channel
                local function response(ret, err)
                    if not ret then
                        channel:close()
                        slave.channel = false
                        slave.status  = 'disconnect'
                        error(err)
                    end
                    master_handler(id, slave.name, shaco.unpackstring(ret))
                end
                response(channel:request(
                    function(id) return assert(socket.ipc_sendfd(id, client_fd)) end,
                    function(id)
                        local head = assert(socket.ipc_read(id, 2))
                        head = sunpack('I2', head)
                        return assert(socket.ipc_read(id, head))
                    end))
            end)
            socket.close(id)
            if not ok then
                shaco.error(err)
            end
        end))
end

--[[
conf = {
    addr = listen address
    worker = worker number
    worker_handler = function(id),
    master_handler = function(id, worker, ...),
        id: socket id
        worker: worker name
        ...: by worker_handler
    end,
}
]]
local function mworker(conf)
    conf.worker = conf.worker or 1
    shaco.start(function()
        -- todo: uncomment this
        local sigint = signal.signal(signal.SIGINT, 'SIG_DFL')
        signal.signal(signal.SIGINT, 
            function(sig)
                signal.signal(signal.SIGCHLD, 'SIG_DFL')
                sigint()
            end)
        signal.signal(signal.SIGCHLD, 
            function(sig, pid, reason, code, extra)
                local name = pid
                for _, w in ipairs(_workers) do
                    if w.pid == pid then
                        w.pid = false
                        w.channel:close()
                        w.channel = false
                        w.status = 'exited'
                        name = w.name
                        break
                    end
                end
                shaco.error(sformat('Worker %s exit due %s(%d) %s', 
                    name, reason, code, extra))
            end)
        if conf.master_init then
            conf.master_init()
        end
        start_listen(conf)
        if prefork_workers(conf) ~= 'child' then
            shaco.fork(function()
                while true do
                    if prefork_workers(conf) ~= 'child' then
                        shaco.sleep(1000)
                    else break
                    end
                end
            end)
        end
    end)
end

return mworker
