local shaco = require "shaco"

shaco.start(function()
    local gated  = assert(shaco.uniqueservice('gate_d'))
    shaco.call(gated, 'lua', 'open', {maxclient=2048, address='127.0.0.1:1234'})
end)
