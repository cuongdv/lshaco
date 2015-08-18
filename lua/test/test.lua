local shaco = require "shaco"

local begin = false
local vhandle

shaco.start(function()
    shaco.trace("publish...")
    shaco.publish("test")
    shaco.trace("uniquemodule...")
    vhandle = shaco.uniquemodule("test1", true, 
        function(type, handle)
            print ("monitor:", type, handle)
        end)
    shaco.trace("uniquemodule return:", vhandle)

    shaco.timeout(1000, function()
        if not begin then
            begin = true
            shaco.send(vhandle, shaco.pack("ping"))
        end
    end)
    shaco.dispatch("um", function(session, source, v)
        if v=="pong" then
            shaco.send(vhandle, shaco.pack("ping"))
        end
    end)
end)
