local shaco = require "shaco"

shaco.start(function()
    local co1, co2
    local i1=0
    local i2=0
    shaco.fork(function()
        co1 = coroutine.running()
        while true do
            shaco.wait()
            i1=i1+1
            print ('co1 run', i1)
            shaco.wakeup(co2)
        end
    end)
    shaco.fork(function()
        co2 = coroutine.running()
        while true do
            i2=i2+1
            print ('co2 run', i2)
            shaco.wakeup(co1)
            shaco.wait()
        end
    end)
end)
