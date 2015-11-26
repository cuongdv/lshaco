local shaco = require "shaco"

shaco.start(function()
    print ('query service1 ...')
    local handle = shaco.queryservice('.service1')
    print ('query service1 return handle:', handle)
end)
