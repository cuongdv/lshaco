local shaco = require "shaco"

shaco.start(function()
    local function tick()
        print ('tick')
        shaco.timeout(1000, tick);
    end
    shaco.timeout(1000, tick);
    shaco.fork(function()
      while true do
          print ('sleep')
          shaco.sleep(1000)
      end
    end)
end)
