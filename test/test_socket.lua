local shaco = require "shaco"
local socket = require "socket"

shaco.start(function()
    shaco.fork(function()
        local lid= assert(socket.listen("127.0.0.1", 1234))
        print ('listen:'..lid)
        socket.start(lid, function(id)
            shaco.fork(function()
                print ('accept:'..id)
                socket.start(id)
                socket.readenable(id, true)
                for i=1,10 do
                    local s = assert(socket.read(id, '\n'))
                    print ('recv:'..s)
                    assert(socket.send(id, s..'\n'))
                end
            end)
        end)
    end)

    shaco.fork(function()
        local id = assert(socket.connect("127.0.0.1", 1234))
        print ('connect ok:'..id)
        socket.readenable(id, true)
        for i=1,10 do
            assert(socket.send(id, tostring(i)..'\n'))
            print('send:'..assert(socket.read(id, '\n')))-- == tostring(i))
        end
    end)
end)
