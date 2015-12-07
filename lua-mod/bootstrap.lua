local shaco = require "shaco"

shaco.start(function()
    local handle
    if shaco.getenv('console') == '1' then
        assert(shaco.luaservice('console'))
    end
    if tonumber(shaco.getenv('slaveid')) then
        if shaco.getenv('standalone') then
            assert(shaco.luaservice('master'))
        end
        handle = assert(shaco.luaservice('slave'))
        shaco.command('REG', 'slave '..handle)
    end
    handle = assert(shaco.luaservice('service'))
    shaco.command('REG', 'service '..handle)
end)
