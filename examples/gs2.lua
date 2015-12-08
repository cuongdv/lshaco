local shaco = require "shaco"

shaco.start(function()
    shaco.register('gs2')
    print ('register gs2 ok')
    local handle = shaco.queryservice('gs1')
    print ('query gs1 return '..string.format('%0x', handle))
end)
