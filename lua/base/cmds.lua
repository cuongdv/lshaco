local shaco = require "shaco"

local clients = {}
local cmdctl_handle 
local cmdctl_me

local WELCOME = [[
______________________________________________
|              WELCOME TO SHACO              |
______________________________________________
]]

local function check_total_response(c)
    if c.sendcnt == c.recvcnt then
        shaco.send(c.source, shaco.pack(c.id, "."))
        clients[c.id] = nil
    end
end

local OP = {}

OP.REQ = function(source, id, info)
    if info == "hi" then
        shaco.send(source, shaco.pack(id, WELCOME))
        shaco.send(source, shaco.pack(id, '.'))
    else
        local c = clients[id]
        assert(c == nil) 
        c = {
            source = source,
            id = id,
            sendcnt = 0,
            recvcnt = 0,
        }
        clients[id] = c
        if info == "help" then
            shaco.send(cmdctl_me, shaco.pack(id, info))
            c.sendcnt = 1
        else
            c.sendcnt = shaco.broadcast(cmdctl_handle, shaco.PTYPE_UM, shaco.pack(id, info))
        end
        check_total_response(c)
    end
end

OP.RES = function(source, id, info, pure)
    local c = clients[id]
    if c then
        c.recvcnt = c.recvcnt+1
        if not pure then
            info = "["..c.recvcnt.."] "..(info or "ok")
        end
        shaco.send(c.source, shaco.pack(id, info))
        check_total_response(c)
    end
end

OP.DISCONN = function(source, id)
    clients[id] = nil
end

shaco.start(function()
    shaco.publish("cmds")
    cmdctl_handle = shaco.subscribe("cmdctl")
    cmdctl_me = shaco.queryid("cmdctl")
    assert(cmdctl_me, "no cmdctl")

    shaco.dispatch("um", function(_, source, id, type, info, pure)
        OP[type](source, id, info, pure)
    end)
end) 
