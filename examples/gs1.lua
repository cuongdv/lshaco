local shaco = require "shaco"

shaco.start(function()
    shaco.register('gs1')
    print ('register gs1 ok')
    local handle = shaco.queryservice('gs2')
    print ('query gs2 return '..string.format('%0x', handle))
end)
