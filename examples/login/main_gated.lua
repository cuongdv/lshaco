local shaco = require "shaco"

shaco.start(function()
    local logind = shaco.queryservice('logind')
    local gated  = assert(shaco.uniqueservice('gated '..logind))
    shaco.call(gated, 'lua', 'open', {name='gate1', maxclient=1024, address='127.0.0.1:1234'})
end)
