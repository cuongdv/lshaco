local shaco = require "shaco"

shaco.start(function()
    if shaco.getenv('console') == '1' then
        assert(shaco.luaservice('console'))
    end
    if tonumber(shaco.getenv('slaveid')) then
        if shaco.getenv('standalone') then
            assert(shaco.luaservice('master'))
        end
        assert(shaco.luaservice('slave'))
    end
    assert(shaco.luaservice('service'))
end)
