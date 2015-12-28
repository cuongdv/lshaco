local shaco = require "shaco"
local socket = require "socket"
local socketchannel = require "socketchannel"
local process = require "process.c"

local nworker = tonumber(...) or 1

local slaves = {}
local slaves_iter = 0

local function worker(pipefd)
    local pipe = assert(socket.bind(pipefd, 'IPC'))
    socket.readon(pipe)
    print ('workder pipe:', pipe)
    while true do
        print ('ipc.. read...');
        local newfd = assert(socket.ipc_readfd(pipe))
        print ('ipc.. read ok');
        shaco.fork(function(fd)
            local pid = process.getpid()
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
            end
            print (string.format('Slave [%d] close sock %d', pid, id))
            assert(socket.ipc_send(pipe, 'exit\n'))
            socket.close(id)
        end, newfd)
    end
end

local function fork_worker(n, listen_sock)
    local pid, pipe = assert(process.fork())
    if pid == 0 then
        print ('I am child')
        socket.close(listen_sock)
        process.settitle('worker process')
        shaco.kill('console')
        for i=1, #slaves do
            local s = slaves[i]
            if s[2] then
                s[2]:close()
            end
        end
        slaves = nil
        socket.clear_pool()
        shaco.fork(worker, pipe)
    else
        print ('I am parent, my child is '..pid)
        process.settitle('master process')
        local id = assert(socket.bind(pipe, 'IPC'))
        socket.readon(id)
        local sc = assert(socketchannel.create{id=id})
        slaves[#slaves+1] = {pid, sc}
        if #slaves < n then
            fork_worker(n, listen_sock)
        end
    end
end

local function start_listen(addr)
    local listen_sock = assert(socket.listen(
        addr, function(id)
            print ('1111')
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
            local sc = slave[2]
            local data = sc:request(
                function(id)
                    return socket.ipc_sendfd(id, newfd)
                end,
                function(id)
                    print ('Master request return ----------')
                    return assert(socket.ipc_read(id, '\n'))
                end)
           -- socket.readon(pipe)
            --local data = assert(socket.recvmsg(pipe))
            print (string.format("Master [%d] get %s from slave [%d:%d]", 
                pid, data, iter, slave[1]))
            --print (string.format('Master [%d] sleep 3s, then close sock %d', pid, id))
            --shaco.sleep(3000)
            print (string.format('Master [%d] close sock %d', pid, id))
            socket.start(id)
            socket.close(id)
        end))
    print ('listen on '..addr..' '..listen_sock)
    return listen_sock
end

shaco.start(function()
    local listen_sock = start_listen('127.0.0.1:1234')
    fork_worker(nworker, listen_sock)
end
