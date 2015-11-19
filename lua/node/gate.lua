local shaco = require "shaco"
local gateserver = require "gateserver"
local socket = require "socket.c"
local pb = require "protobuf"
local sfmt = string.format
local chan = require "chan"
require "msg_error"
require "msg_client"
require "msg_server"

local request_handle

local function route_to_conn(connid, msgid, msg, sz)
    shaco.sendpack_um(connid, msgid, msg, sz)
end

local function send2conn(connid, msgid, name, value)
    pb.encode(name, value, function(buffer, len)
        shaco.sendpack_um(connid, msgid, buffer, len)
    end)
end

local function send2handle(handle, connid, msgid, name, value)
    pb.encode(name, value, function(buffer, len)
        local msg, sz = shaco.pack(IDUM_GATE, connid, msgid, buffer, len)
        shaco.send(handle, msg, sz)
    end)
end


local handle = {}
function handle.accept(c) end
function handle.connect(c) end
function handle.login(c) end
function handle.reject(id, reason) 
    if reason == 1 then
        reason = SERR_GATEHANDLEEXIT
    else
        reason = SERR_GATEFULL
    end
    send2conn(id, IDUM_LOGOUT, "UM_LOGOUT", {err=reason})
end
function handle.disconnect(c, forward)
    chan.exit(c.id)
    if forward then
        send2handle(request_handle, c.id, IDUM_NETDISCONN, "UM_NETDISCONN", {})
    end
end

local function readpack(c)
    if c.head == nil then
        c.head = c.buffer:pop("*2")
        if c.head == nil then 
            return 
        end
        if c.head == 0 then
            c.head = nil
            gateserver.disconnect(c, true, "Invalid message")
            return
        end
    end
    local msg, sz = c.buffer:popbytes(c.head)
    if msg then
        c.head = nil
        return msg, sz
    end
end

local function parsepack(c, msg, sz)
    local msgid, msg, sz = shaco.unpack_msgid(msg, sz)
    if not msgid then
        return 1
    end
    if msgid >= IDUM_GATEB and msgid < IDUM_GATEE then
        if msgid ~= IDUM_HEARTBEAT then
            shaco.trace(sfmt("Client %d receive msg: %u, %d", c.id, msgid, sz))
            shaco.send(request_handle, shaco.pack(IDUM_GATE, c.id, msgid, msg, sz))
        end
    end
end

function handle.message(c)
    while true do
        local msg, sz = readpack(c)
        if not msg then break end
        if parsepack(c, msg, sz) then
            gateserver.disconnect(c, true, "Handle message error")
            c.buffer.freebytes(msg)
            return
        end
        c.buffer.freebytes(msg)
    end
end

shaco.start(function()
    pb.register_file("../res/pb/enum.pb")
    pb.register_file("../res/pb/struct.pb")
    pb.register_file("../res/pb/msg_client.pb")
    pb.register_file("../res/pb/msg_server.pb")

    shaco.publish("gate")
    request_handle = shaco.subscribe("game")
    assert(request_handle)

    gateserver.start(handle, {
        timeout = 1000,
        address = shaco.getenv("gateaddress"),
        slimit = shaco.getenv("clientslimit"),
        rlimit = shaco.getenv("clientrlimit"),
        livetime = shaco.getenv("clientlive", 3)*1000,
        logintime = 60*1000,
        logouttime = 5*1000,
        clientmax = shaco.getenv("clientmax"),
    })

    shaco.dispatch("um", function(_,_, msgid, p1,p2,p3,p4,p5) 
        if msgid == IDUM_GATE then
            local connid, subid, msg, sz = p1,p2,p3,p4
            assert(connid)
            assert(subid)
            local c = gateserver.clients[connid]
            if not c then
                shaco.trace(sfmt("Client %d send %d sz %d, but closed", connid, subid, #msg))
                return
            end
            shaco.trace(sfmt("Client %d send %d sz %d", connid, subid, #msg))
            if subid == IDUM_LOGOUT then
                local v, err = pb.decode("UM_LOGOUT", msg, sz)
                assert(v, err)
                local reason = "logout:"..v.err
                if v.err == SERR_OKUNFORCE then
                    gateserver.disconnect(c, false, reason)
                elseif v.err == SERR_OK then
                    gateserver.disconnect(c, true, reason)
                else
                    route_to_conn(connid, subid, msg, sz)
                    gateserver.disconnect(c, false, reason) 
                end
            else
                route_to_conn(connid, subid, msg, sz)
            end 
        elseif msgid == IDUM_SUBSCRIBE then
            local connid, chanid = p1,p2
            assert(connid)
            assert(chanid)
            local c = gateserver.clients[connid]
            if c then
                chan.subscribe(chanid, connid)
            end
        elseif msgid == IDUM_SUBSCRIBE then
            local connid, chanid = p1,p2
            assert(connid)
            assert(chanid)
            local c = gateserver.clients[connid]
            if c then
                chan.unsubscribe(chanid, connid)
            end
        elseif msgid == IDUM_PUBLISH then
            local connid, chanid, subid, msg, sz = p1,p2,p3,p4,p5
            assert(connid)
            assert(chanid)
            --local c = gateserver.clients[connid]
            --if c then
            if chanid == nil then
                for connid, c in pairs(gateserver.clients) do
                    route_to_conn(connid, subid, msg, sz)
                end
                shaco.trace(sfmt("chan[0] publish msg:%d", msgid))
            else
                chan.publish(chanid, subid, msg, sz)
            end
        end
    end)
end)
