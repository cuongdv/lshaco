local shaco = require "shaco"
local gateserver = require "gateserver"
local tbl = require "tbl"
local util = require "util.c"

local request_handle

local handle = {}
function handle.accept(c) end
function handle.connect(c) end
function handle.login(c) end
function handle.reject(id, reason) end
function handle.disconnect(c, forward, reason) 
    --shaco.trace("disconnect:"..c.id, reason)
end

--function handle.message(c)
    --while true do
        --local one = c.buffer:pop("*l")
        --if one then
            --gateserver.send(c, "+PONG\r\n")
            ----gateserver.send(c, one.."\n")
            ----shaco.send(request_handle, shaco.pack(c.id, one.."\n"))
        --else break end
    --end
--end

function handle.message(c)
    while true do
        local h = c.buffer:pop("*2")
        if h then
            local msg, sz = c.buffer:popbytes(h)
            if msg then
                local id, id2 = shaco.unpack(msg, sz)
                assert(id==1)
                assert(id2=="1234567890")

                local s = util.bytes2str(msg, sz)
                gateserver.send(c, string.pack("<s2",s))

                c.buffer.freebytes(msg)
            else break end
        else break end
    end
end

shaco.start(function() 
    --shaco.publish("echo")
    --request_handle = shaco.subscribe("test_game")
    --assert(request_handle)

    gateserver.start(handle, {
        timeout = 1000,
        address = shaco.getstr("gateaddress"),
        livetime = 3000*1000,
        clientmax = shaco.getnum("clientmax"),
    })

    --shaco.dispatch("um", function(_,_,cid,msg,sz)
        --local c = gateserver.clients[cid]
        --if c then
            --gateserver.send(c, msg)
        --end
    --end)
end)
