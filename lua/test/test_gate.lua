local shaco = require "shaco"
local gateserver = require "gateserver"
local tbl = require "tbl"
local util = require "util.c"
local cmdcall = require "cmdcall"

local request_handle

local handle = {}
function handle.accept(c) end
function handle.connect(c) end
function handle.login(c) end
function handle.reject(id, reason) end
function handle.disconnect(c, forward, reason) 
    shaco.trace("disconnect:"..c.id, reason)
end
function handle.message(c)
    while true do
        local one = c.buffer:pop("*l")
        if one then
            shaco.send(request_handle, shaco.pack(c.id, one.."\n"))
        else break end
    end
end

shaco.start(function() 
    shaco.publish("test_gate")
    --request_handle = shaco.subscribe("test_game", true)
    --assert(request_handle)
    print ("start wait test_game....")
    request_handle = shaco.uniquemodule("test_game", true,
        function(type)
            print ("uniquemodule type:"..type)
        end)
    print ("test_game get")
    gateserver.start(handle, {
        timeout = 1000,
        address = shaco.getstr("gateaddress"),
        livetime = 3000*1000,
        client_max = shaco.getenv("clientmax"),
    })

    shaco.dispatch("um", function(_,_,cid,msg,sz)
        local c = gateserver.clients[cid]
        if c then
            gateserver.send(c, msg)
        end
    end)
end)
