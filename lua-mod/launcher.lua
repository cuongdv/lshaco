local shaco = require "shaco"

shaco.start(function()
    local instances = {}

    local CMD = {}
    
    function CMD.LAUNCH(source, name)
        local handle = tonumber(shaco.command('LAUNCH', 'lua '..name))
        if not handle then
            error(string.format('Launch %s fail', name))
        end
        instances[handle] = shaco.response()
    end

    function CMD.LAUNCHOK(source)
        local response = instances[source]
        if response then
            instances[source] = nil
            response(source)
        end
    end

    function CMD.LAUNCHFAIL(source)
        local response = instances[source]
        if response then
            instances[source] = nil
            response(false)
        end
    end

    shaco.dispatch('lua', function(source, session, cmd, ...)
        local f = CMD[cmd]
        f(source, ...)
    end)
end)
