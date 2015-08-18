local shaco = require "shaco"

shaco.start(function()
    print ("start----------")
    --shaco.timeout(1000, function()
        --print ("*** timeout")
    --end)
    print ("----------------------")
    for i=1, 10 do
        shaco.sleep(1000)
        print ("tick")
    end
    print ("----------------------")
end)
