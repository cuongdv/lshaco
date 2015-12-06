local shaco = require "shaco"

shaco.register_protocol {
    id = shaco.TTEXT,
    name = "text",
    unpack = shaco.tostring,
}

shaco.start(function()
    local S2
    shaco.dispatch('text', function(source, session, value)
        print ('service2 read:'..value)
        shaco.send(S2, 'text', 'ping')
    end)
    
    shaco.register('.service1')
    print ('query service2 ...')
    S2 = shaco.queryservice('.service2')
    print ('query service2 return handle:'..S2)
    
    shaco.send(S2, 'text', 'ping')
end)
