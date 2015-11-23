local shaco = require "shaco"

shaco.start(function()
    local handle = assert(shaco.luaservice('test_socket'))
    print (handle)
end)
