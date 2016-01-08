local shaco = require "shaco"

shaco.start(function()
    local logind = shaco.queryservice('logind')
    local gated  = assert(shaco.uniqueservice('gated '..logind))
    shaco.call(gated, 'lua', 'open', {name='gate1', maxclient=1024, address='127.0.0.1:8001', expire_number=0})
end)
