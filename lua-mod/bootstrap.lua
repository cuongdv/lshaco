local shaco = require "shaco"
shaco.start(function()
    if shaco.getenv('console') == '1' then
        assert(shaco.luaservice('console'))
    end
    assert(shaco.luaservice('service'))
end)
