local shaco = require "shaco"

shaco.start(function()
    local handle
    handle = assert(tonumber(shaco.command('LAUNCH', 'lua launcher')))
    shaco.command('REG', 'launcher '..handle)

    if shaco.getenv('console') then
        handle = assert(shaco.uniqueservice('console'))
        shaco.command('REG', 'console '..handle)
    end
    if tonumber(shaco.getenv('slaveid')) then
        if shaco.getenv('standalone') then
            assert(shaco.uniqueservice('master'))
        end
        handle = assert(shaco.uniqueservice('slave'))
        shaco.command('REG', 'slave '..handle)
    end
    handle = assert(shaco.uniqueservice('service'))
    shaco.command('REG', 'service '..handle)

    pcall(shaco.uniqueservice(shaco.getenv('start') or 'main'))
end)
