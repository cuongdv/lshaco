local shaco = require "shaco"

shaco.start(function()
    local S2
    shaco.dispatch('lua', function(source, session, value)
        print ('service2 read:'..value)
        shaco.send(S2, shaco.pack('ping'))
    end)
    
    shaco.register('.service1')
    print ('query service2 ...')
    S2 = shaco.queryservice('.service2')
    print ('query service2 return handle:'..S2)
    
    shaco.send(S2, shaco.pack('ping'))
end)
