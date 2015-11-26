local shaco = require "shaco"

shaco.start(function()
    local S1
    shaco.dispatch('lua', function(source, session, value)
        print ('service1 read:'..value)
        shaco.send(S1, shaco.pack('pong'))
    end)

    print ('query service1 ...')
    S1 = shaco.queryservice('.service1')
    print ('query service1 return handle:'..S1)

    shaco.register('.service2')
end)
