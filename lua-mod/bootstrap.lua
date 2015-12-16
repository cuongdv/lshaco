local shaco = require "shaco"

shaco.start(function()
    local handle
    if shaco.getenv('console') then
        assert(shaco.newservice('console'))
    end
    if tonumber(shaco.getenv('slaveid')) then
        if shaco.getenv('standalone') then
            assert(shaco.newservice('master'))
        end
        handle = assert(shaco.newservice('slave'))
        shaco.command('REG', 'slave '..handle)
    end
    handle = assert(shaco.newservice('service'))
    shaco.command('REG', 'service '..handle)

    pcall(shaco.newservice(shaco.getenv('start') or 'main'))
end)
