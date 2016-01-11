local shaco = require "shaco"

shaco.start(function()
    local logind = assert(shaco.uniqueservice('logind'))
    if not shaco.getenv('isworker') then
        shaco.register('logind', logind)
    end
end)
