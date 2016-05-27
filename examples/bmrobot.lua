local shaco = require "shaco"
local socket = require "socket"
local tbl = require "tbl"
local pb = require "protobuf"
local MRES = require "msg_resname"
local MREQ = require "msg_reqname"
local sunpack = string.unpack

local TRACE = shaco.getenv("trace")
local IP, PORT = string.match(shaco.getenv("host"), "([^:]+):?(%d+)$")
assert(IP)
assert(PORT)
local ROBOTID = tonumber(shaco.getenv("robotid"))
local CLIENT_COUNT = tonumber(shaco.getenv("nclient")) or 1000

local start_time
--local connectok = 0
local loginok = 0
local loginerr = 0
local clients = {}
--local stat = 0
--local pack_count = tonumber(shaco.getenv("pack_count")) or 1000
local read_count = 0

local move_batch = 1000
local move_stat = 0
local move_intv = 200
local move_stat_time = 0

local function COUNT()
    local n = CLIENT_COUNT
    if n%2==0 then
        return n*11 + n*(n-1), n*11 + n*(n/2)-n/2
    else
        return n*11 + n*(n-1), n*11 + n*(n//2)
    end
end

-------------------------------------------
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
    if reqid == IDUM_LOGIN or
       reqid == IDUM_CREATEROLE then
        return IDUM_ROLELIST
    elseif reqid == IDUM_SELECTROLE then
        return IDUM_ENTERGAME
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

local function rpc(id, reqid, v)
    info_trace(reqid, "<")
    local resid = responseid(reqid)
    socket.send(id, encode(reqid, v)) 
    while true do
        local h = assert(socket.read(id, 2))
        h = sunpack('<I2', h)
        local s = assert(socket.read(id, h))
        local mid, r = decode(s)
        local now = shaco.now()
        io.stdout:write(string.format("logined [%d] use time:%d read [%d] %d %d\r", loginok, now-start_time, read_count, COUNT()))
        if mid == resid then
            info_trace(mid, ">")
            return r
        end
        info_trace(mid, "*")
    end
end

local function create_robot(account, rolename) 
    local id 
    local ok, err = pcall(function()
        id = assert(socket.connect(IP, PORT))
        socket.readon(id)
        local v = rpc(id, IDUM_LOGIN, {acc=account, passwd="123456"})
        if not v.roles then
            rpc(id, IDUM_CREATEROLE, {tpltid=1, name=rolename})
        end
        rpc(id, IDUM_SELECTROLE, {index=0})
    end)
    if not ok then
        print (err)
    else
        return id
    end
end
-------------------------------------------
local function send(id, msgid, v)
    socket.send(id, encode(msgid, v)) 
end

local function loginstat(ok)
    if ok then
        loginok = loginok+1
    else
        loginerr = loginerr+1
    end
    if loginok+loginerr == CLIENT_COUNT then
        local now = shaco.now()
        print(string.format("logined [%d + %d] use time:%d read [%d] %d %d", 
        loginok, loginerr, now-start_time, read_count, COUNT()))
    end
end

local function movestat()
    move_stat = move_stat+1
    if move_stat == move_batch then
        local now = shaco.now()
        io.stdout:write(string.format("move stat: pqs: %f\r", move_batch/(now-move_stat_time)*1000))
        move_stat = 0
        move_stat_time = now
    end
end

local function move(id)
    local start_time = shaco.now()
    move_stat = 0
    move_stat_time = shaco.now()
    local last_move_time
    local x=100
    local y=math.random(1, 200)
    local speed = 350
    local dirx = 1
    while true do
        local dt
        if last_move_time then
            shaco.sleep(move_intv)
            dt = move_intv
        else
            dt = 0
        end
        
        local dx = math.floor(speed*dt/1000)
        if dirx>0 then
            if x>2000 then dirx=-1 end
        else
            if x<100 then dirx=1 end
        end
        x = x+dx*dirx
        send(id, IDUM_MOVEREQ, {posx=x,posy=y,speed=speed,dirx=dirx,diry=0})
        
        last_move_time = shaco.now()
        movestat()
        
        local now = shaco.now()
        if now - start_time > math.random(60*1000, 65*1000) then
            break
        end
    end
end

local function client(uid)
    local account  = string.format("robot_acc_%u", uid)
    local rolename = string.format("robot_name_%u", uid)

    while true do
        local id = create_robot(account, rolename)
        loginstat(id)
        if id then
            shaco.fork(function()
                local ok, err = pcall(function()
                    while true do
                        assert(socket.read(id))
                    end
                end)
                if not ok then
                    shaco.error(err)
                end
            end)
            local ok, err = pcall(function()
                move(id)
            end)
            if not ok then
                shaco.error(err)
            end
            socket.close(id)
        end
    end
end

local tick = 0
local logined = false
shaco.start(function()
    pb.register_file("../res/pb/enum.pb")
    pb.register_file("../res/pb/struct.pb")
    pb.register_file("../res/pb/msg_client.pb")
    start_time = shaco.now()
    math.randomseed(start_time//1000)
    for i=1, CLIENT_COUNT do
        local co = shaco.fork(client,ROBOTID+i-1)
        table.insert(clients,co)
    end
end)
