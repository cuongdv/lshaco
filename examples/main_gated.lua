local shaco = require "shaco"

shaco.start(function()
    local handle = shaco.uniqueservice('gated')
    shaco.call(handle, 'lua', 'open', {maxclient=1024, address='127.0.0.1:1234'})
    print ('open ok')
end)
