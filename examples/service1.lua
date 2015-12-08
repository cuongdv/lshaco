local shaco = require "shaco"

shaco.start(function()
    local S2
    local i = 0
    shaco.dispatch('text', function(source, session, value)
        print ('service2 read:'..value)
        i=i+1
        if i<10000 then
        shaco.send(S2, 'text', 'ping')
        print ('service2 send: ping '..i)
    end
    end)
   
    print ('register service1 ...')
    shaco.register('service1')
    print ('query service2 ...')
    S2 = shaco.queryservice('service2')
    print ('query service2 return handle:'..S2)
    
    shaco.send(S2, 'text', 'ping')
end)
