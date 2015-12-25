local shaco = require "shaco"
local socket = require "socket"
local process = require "process.c"

local slaves = {}
local slaves_iter = 0

local function tunnel(pipefd)
    local pipe = assert(socket.bind(pipefd, 'IPC'))
    socket.readon(pipe)
    while true do
        local newfd = assert(socket.read_fd(pipe))
        shaco.fork(function(fd)
            local pid = process.getpid()
            local id = assert(socket.bind(fd))
            print (string.format('Slave [%d] accept sock %d', pid, id))
            socket.readon(id)
            while true do
                local s = assert(socket.read(id, '\r\n'))
                print (string.format('Slave [%d] read %s', pid, s))
                if s == 'exit' then
                    print (string.format('Slave [%d] exit ...', pid))
                    break
                end
                socket.send(id, s..'\n')
            end
            print (string.format('Slave [%d] close sock %d', pid, id))
            socket.close(id)
            assert(socket.sendmsg(pipe, 'exit'))
        end, newfd)
    end
end

shaco.start(function()
    local addr = '127.0.0.1:1234'
    local listen_sock = assert(socket.listen(
        addr, function(id)
            local pid = process.getpid()
            print (string.format('Master [%d] accpet sock %d', pid, id))
            slaves_iter = slaves_iter+1
            if slaves_iter > #slaves then
                slaves_iter = 1
            end
            local slave = slaves[slaves_iter]
            print (string.format("Master [%d] select slave [%d:%d] ...", 
                pid, slaves_iter, slave[1]))
            local pipe = slave[2]
            -- todo: rate appear Broken pipe, and pipe is disappear, why?
            assert(socket.send_fd(pipe, socket.getfd(id)))
            socket.readon(pipe)
            local data = assert(socket.recvmsg(pipe))
            print (string.format("Master [%d] get %s from slave [%d:%d]", 
                pid, data, slaves_iter, slave[1]))
            print(string.format('Master [%d] sleep 3s, then close sock %d', pid, id))
            shaco.sleep(3000)
            socket.start(id)
            socket.close(id)
        end))
    print ('listen on '..addr..' '..listen_sock)
    local pid, pipe = 1
    for i=1, 3 do
        if pid > 0 then
            pid, pipe = assert(process.fork())
            if pid == 0 then
                print ('I am child')
                socket.close(listen_sock)
                process.settitle('worker process')
                shaco.kill('console')
                shaco.fork(tunnel, pipe)
            else
                print ('I am parent, my child is '..pid)
                process.settitle('master process')
                local fd = assert(socket.bind(pipe, 'IPC'))
                slaves[#slaves+1] = {pid, fd}
            end
        end
    end

    --local print = shaco.error
    --local fd = assert(socket.connect(addr))
    --socket.readon(fd)
    --local pid = assert(process.fork())
    --if pid == 0 then
    --    print ('I am child')
    --    assert(socket.send(fd, 'child send\n'))
    --    print('child get:'..assert(socket.read(fd)))
    --    shaco.sleep(3000)
    --    assert(socket.send(fd, 'child send 2\n'))
    --    print ('child get2:'..assert(socket.read(fd)))
    --else
    --    print ('I am parent, my child is '..pid)
    --    assert(socket.send(fd, 'parent send\n'))
    --    print('parent get:'..assert(socket.read(fd)))
    --    socket.close(fd)
    --    print ('parnet close fd')
    --end
end)
