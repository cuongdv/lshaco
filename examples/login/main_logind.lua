local shaco = require "shaco"

shaco.start(function()
    local logind = assert(shaco.uniqueservice('logind'))
    shaco.register('logind', logind)
end)
