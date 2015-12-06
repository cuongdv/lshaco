local shaco = require "shaco"
local util = require "util.c"

local gate_handle

shaco.start(function()
    shaco.publish("test_game")
    gate_handle = shaco.subscribe("test_gate")
    assert(gate_handle)

    shaco.dispatch("um", function(_,_,cid,msg)
        shaco.send(gate_handle, shaco.pack(cid, msg))
    end)
end)
