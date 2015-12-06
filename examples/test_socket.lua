local shaco = require "shaco"
local socket = require "socket"

shaco.start(function()
    shaco.fork(function()
        local id = assert(socket.listen(
            "127.0.0.1:1234",
            function(id)
                print ('accept:'..id)
                socket.start(id)
                socket.readon(id)
                for i=1,10 do
                    local s = assert(socket.read(id, '\n'))
                    print ('recv:'..s)
                    assert(socket.send(id, s..'\n'))
                end
            end))
        print ('listen:'..id)
    end)

    shaco.fork(function()
        local id = assert(socket.connect("127.0.0.1:1234"))
        print ('connect ok:'..id)
        socket.readon(id)
        for i=1,10 do
            assert(socket.send(id, tostring(i)..'\n'))
            print ('send:'..i)
            assert(socket.read(id, '\n'))
        end
    end)
end)
