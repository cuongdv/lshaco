local shaco = require "shaco"

shaco.start(function()
    local co1
    shaco.fork(function()
        co1 = coroutine.running()
        print ('co1 sleep 5s...')
        assert(shaco.sleep(5000)=='BREAK')
        print ('co1 sleep break after 3s.')
    end)
    shaco.fork(function()
        print ('co2 sleep 3s...')
        shaco.sleep(3000)
        shaco.wakeup(co1)
        print ('co2 has sleep 3s, now break co1')
    end)
    shaco.fork(function()
        while true do
            print ('    co3 sleep 1s...')
            shaco.sleep(1000)
            print ('    co3 has sleep 1s')
        end
    end)
    local function tick()
        print ('    tick per second...')
        shaco.timeout(1000, tick);
    end
    shaco.timeout(1000, tick);
end)
