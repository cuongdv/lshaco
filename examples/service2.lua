local shaco = require "shaco"

shaco.register_protocol {
    id = shaco.TTEXT,
    name = "text",
    unpack = shaco.tostring,
}

shaco.start(function()
    local S1
    shaco.dispatch('text', function(source, session, value)
        print ('service1 read:'..value)
        shaco.send(S1, 'text', 'pong')
    end)

    print ('query service1 ...')
    S1 = shaco.queryservice('.service1')
    print ('query service1 return handle:'..S1)

    shaco.register('.service2')
end)
