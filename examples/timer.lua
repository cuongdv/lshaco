local shaco = require "shaco"

shaco.start(function()
    local function tick()
        print ('tick per second')
        shaco.timeout(1000, tick);
    end
    shaco.timeout(1000, tick);
    shaco.fork(function()
      while true do
          print ('sleep per second')
          shaco.sleep(1000)
      end
    end)
end)
