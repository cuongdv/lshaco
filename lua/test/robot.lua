local shaco = require "shaco"
local socket = require "socket"
local util = require "util.c"
local tbl = require "tbl"
local pb = require "protobuf"
local MRES = require "msg_resname"
local MREQ = require "msg_reqname"

local ip=shaco.getenv("ip")
local port=shaco.getenv("port")
local client_count = shaco.getenv("client_count")
local robotid  = tonumber(shaco.getenv("robotid"))
local TRACE = shaco.getenv("trace")
local start_time
local connectok = 0
local loginok = 0
local clients = {}
local stat = 0
local pack_count = tonumber(shaco.getenv("pack_count")) or 1000
local read_count = 0

local function COUNT()
    local n = client_count
    if n%2==0 then
        return n*11 + n*(n-1), n*11 + n*(n/2)-n/2
    else
        return n*11 + n*(n-1), n*11 + n*(n//2)
    end
end

local function client(uid)
    local id = assert(socket.connect(ip,port))
    socket.readenable(id, true)

    local function info_trace(msgid, tag)
        if not TRACE then return end
        if tag == "<" then
            print(string.format("%s--[%s:%d]", tag, MREQ[msgid], msgid))
        elseif tag == ">" then
            print(string.format("--%s[%s:%d]", tag, MRES[msgid], msgid))
        else
            print(string.format("  %s[%s:%d]", tag, MRES[msgid], msgid))
        end
    end

    local function responseid(reqid)
        if reqid == IDUM_LOGIN then
            return IDUM_ROLELIST
        else
            return IDUM_RESPONSE
        end
    end

    local function encode(mid, v)
        local s = pb.encode(MREQ[mid], v)
        local l = #s+2
        return string.char(l&0xff, (l>>8)&0xff)..
            string.char(mid&0xff, (mid>>8)&0xff)..s
    end
  
    local function decode(s)
        local mid = string.byte(s,1,1)|(string.byte(s,2,2)<<8)
        --print (mid)
        return mid, pb.decode(MRES[mid], string.sub(s,3))
    end
      
    local function wait(msgid)
        while true do
            local h = assert(socket.read(id, "*2"))
            local s = assert(socket.read(id, h))
            --print (h, #s)
            local mid, r = decode(s)
            read_count = read_count + 1
            local now = shaco.now()
            --if loginok == client_count then
                util.printr(string.format("logined [%d] use time:%d read [%d] %d %d", loginok, now-start_time, read_count, COUNT()))
            --end
            if mid == msgid then
                info_trace(mid, ">")
                return r
            end
            info_trace(mid, "*")
        end
    end

    local function rpc(reqid, v)
        info_trace(reqid, "<")
        local resid = responseid(reqid)
        socket.send(id, encode(reqid, v)) 
        return wait(resid)
    end

    local account  = string.format("robot_acc_%u", uid)
    local rolename = string.format("robot_name_%u", uid)

    local v = rpc(IDUM_LOGIN, {acc=account, passwd="123456"})
    if #v.roles == 0 then
        rpc(IDUM_CREATEROLE, {tpltid=1, name=rolename})
    end
    rpc(IDUM_SELECTROLE, {index=0})

    loginok = loginok+1
    if loginok == client_count then
        local now = shaco.now()
        util.printr(string.format("logined [%d] use time:%d read [%d] %d %d", loginok, now-start_time, read_count, COUNT()))
    end

    while true do
        assert(socket.read(id, "*a"))
    end

    --wait(0)
    --coroutine.yield()
    --socket.close(id)
end

local function fork(f,...)
    local m = function (...)
        assert(xpcall(f, debug.traceback,...))
    end
    local co = coroutine.create(m)
    assert(coroutine.resume(co, ...))
    return co
end

local function wakeup(co, ...)
    assert(coroutine.resume(co, ...))
end

local tick = 0
local logined = false
shaco.start(function()
    pb.register_file("../res/pb/enum.pb")
    pb.register_file("../res/pb/struct.pb")
    pb.register_file("../res/pb/msg_client.pb")

    start_time = shaco.now()
    for i=1, client_count do
        local co = shaco.fork(client,robotid+i)
        table.insert(clients,co)
    end
end)
