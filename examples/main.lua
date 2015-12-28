local shaco = require "shaco"

shaco.start(function()
    assert(shaco.newservice('echo'))
--    assert(shaco.newservice('process'))
--    assert(shaco.newservice('service1'))
 --   assert(shaco.newservice('service2'))
end)
