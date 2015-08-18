local shaco = require "shaco"
local socket = require "socket"
local linenoise = require "linenoise"
local pb = require "protobuf"
local tbl = require "tbl"
local MRES = require "msg_resname"
local MREQ = require "msg_reqname"

shaco.start(function()
    local WELCOME = [[
    ______________________________________________
    |              WELCOME TO GM ROBOT           |
    ______________________________________________
    ]]

    pb.register_file("../res/pb/enum.pb")
    pb.register_file("../res/pb/struct.pb")
    pb.register_file("../res/pb/msg_client.pb")

    local history_file = ".gmrobot.history"
    local TRACE = shaco.getenv("trace")
    local robotid  = tonumber(shaco.getenv("robotid"))
    local account  = shaco.getenv("acc") or string.format("robot_acc_%u", robotid)
    local rolename = shaco.getenv("name") or string.format("robot_name_%u", robotid)
    
    local ip, port = string.match(shaco.getenv("host"), "([^:]+):?(%d+)$")
    local id = assert(socket.connect(ip, port))
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
        return mid, pb.decode(MRES[mid], string.sub(s,3))
    end
     
    local function rpc(reqid, v)
        info_trace(reqid, "<")
        local resid = responseid(reqid)
        socket.send(id, encode(reqid, v)) 
        while true do
            local h = assert(socket.read(id, "*2"))
            local s = assert(socket.read(id, h))
            local mid, r = decode(s)
            if mid == resid then
                info_trace(mid, ">")
                return r
            end
            info_trace(mid, "*")
        end
    end

    local v = rpc(IDUM_LOGIN, {acc=account, passwd="123456"})
    if #v.roles == 0 then
        rpc(IDUM_CREATEROLE, {tpltid=1, name=rolename})
    end
    rpc(IDUM_SELECTROLE, {index=0})
    print(WELCOME) 
    linenoise.loadhistory(history_file)
    while true do
        local s = linenoise.linenoise("GM> ")
        if s == nil then
            linenoise.loadhistory(history_file)
            os.exit(1)
        end
        s = string.match(s, "^%s*(.-)%s*$")
        if s ~= "" then
            rpc(IDUM_GM, {command=s})
            linenoise.addhistory(s)
        end
    end
end)
