local shaco = require "shaco"
local socket = require "socket"
local socketchannel = require "socketchannel"
local process = require "process.c"

local nworker = tonumber(...) or 1

local slaves = {}
local slaves_iter = 0

local function worker(ipc)
    while true do
        local newfd = assert(socket.ipc_readfd(ipc))
        shaco.fork(function(fd)
            local pid = process.getpid()
            print (string.format('Slave [%d] accept fd %d', pid, fd))
            local id = assert(socket.bind(fd))
            print (string.format('Slave [%d] accept sock %d', pid, id))
            socket.readon(id)
            while true do
                local s = assert(socket.read(id, '\n'))
                print (string.format('Slave [%d] read %s', pid, s))
                if s == 'exit' then
                    print (string.format('Slave [%d] exit ...', pid))
                    break
                end
                socket.send(id, s..'\n')
                print (string.format('Slave [%d] send %s', pid, s))
            end
            print (string.format('Slave [%d] close sock %d', pid, id))
            assert(socket.ipc_send(ipc, 'exit\n'))
            socket.close(id)
        end, newfd)
    end
end

local function ipc(fd)
    local id = assert(socket.bind(fd, 'IPC'))
    socket.readon(id)
    return id
end

local function ipc_channel(fd)
    local id = ipc(fd)
    return assert(socketchannel.create{id=id})
end

local function fork_worker(n)
    process.signal('SIGCHLD', function(sig)
    end)
    process.signal{
        SIGCHLD = function(sig)
        end,

    }
    local fd0, fd1 = assert(socket.pair())
    local pid = assert(process.fork())
    if pid == 0 then
        print ('I am child')
        process.settitle('worker process')
        shaco.kill('console')
        for i=1, #slaves do
            local s = slaves[i]
            if s[2] then
                s[2]:close()
            end
        end
        slaves = nil
        socket.reinit()
        shaco.fork(worker, ipc(fd1))
    else
        print ('I am parent, my child is '..pid)
        process.settitle('master process')
        local ic = ipc_channel(fd0)
        slaves[#slaves+1] = {pid, ic}
        if #slaves < n then
            fork_worker(n)
        end
    end
end

local function start_listen(addr)
    local listen_sock = assert(socket.listen(
        addr, function(id)
            local pid = process.getpid()
            local newfd = socket.getfd(id)
            print (string.format('Master [%d] accpet sock %d', pid, id))
            local iter = slaves_iter+1
            if iter > #slaves then
                iter = 1
            end
            slaves_iter = iter
            local slave = slaves[iter]
            print (string.format("Master [%d] select slave [%d:%d] ...", 
                pid, iter, slave[1]))
            local ic = slave[2]
            local data = ic:request(
                function(id)
                    return socket.ipc_sendfd(id, newfd)
                end,
                function(id)
                    return assert(socket.ipc_read(id, '\n'))
                end)
            print (string.format("Master [%d] get %s from slave [%d:%d]", 
                pid, data, iter, slave[1]))
            shaco.sleep(1000)
            print (string.format('Master [%d] close sock %d', pid, id))
            socket.close(id)
        end))
    print ('listen on '..addr..' '..listen_sock)
end

shaco.start(function()
    start_listen('127.0.0.1:1234')
    fork_worker(nworker)
end)
