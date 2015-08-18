local shaco = require "shaco"
local tbl = require "tbl"
local rcall = shaco.call
local sfmt = string.format
local tinsert = table.insert
local tonumber = tonumber
local floor = math.floor
local pb = require "protobuf"
local user = require "user"
local userpool = require "userpool"
local CTX = require "ctx"
local tprole = require "__tpcreaterole"
local MSG_RESNAME = require "msg_resname"
local REQ = {}

local NODISCONN=0
local DISCONN=1

local function role_base_gen(name, tpid, tp)
    return {
        name=name, 
        tpltid=tpid, 
        roleid=0, 
        create_time=shaco.now()//1000,
        race = tp.OccupationID,
        level = tp.Level,
        sex = tp.sex,
    }
end

local function conn_disconnect(connid, err)
    local msgid = IDUM_LOGOUT
    local v = {err=err}
    local name = MSG_RESNAME[msgid]
    assert(name)
    pb.encode(name, v, function(buffer, len)
        local msg, sz = shaco.pack(IDUM_GATE, connid, msgid, buffer, len)
        shaco.send(CTX.gate, msg, sz)
    end)
end

local function logout(ur, err, disconn) 
	if ur then
		ur:log_in_out_log(0)
	end
    userpool.logout(ur)
    if ur.status >= user.US_GAME then
        ur:exitgame()
    end
    if disconn == DISCONN then
        ur:send(IDUM_LOGOUT, {err=err}) 
    end
    shaco.trace(sfmt("user %s logout, err=%d, disconn=%d", ur.acc, err, disconn))
end

local function check_status(ur, status)
    if ur.status ~= status then
        shaco.warning(sfmt("user %s state need in %d, but real in %d", ur.acc, status, ur.status))
        return 1
    end
end

local function switch_status(ur, status)
    ur.status = status
    shaco.trace(sfmt("user %s switch state to %s", ur.acc, status))
end

-- handle
REQ[IDUM_LOGIN] = function(connid, v)
    local acc = v.acc
    shaco.trace(sfmt("user %s login ... ", connid, acc))
    local ur = userpool.find_byconnid(connid)
    if ur then
        return
    end
    -- todo check
    if #acc <= 0 then
        conn_disconnect(connid, SERR_ACCVERIFY)
        return
    end
    local data = rcall(CTX.db, "L.rolelist", acc)
    if not data then
        conn_disconnect(connid, SERR_DB)
        return
    end
    local rl = {}
    for _, v in ipairs(data) do
        local base = pb.decode("role_base", v.base)
        base.roleid = tonumber(v.roleid)
        tinsert(rl, base)
    end
    ur = userpool.find_byacc(acc)
    if ur then
        logout(ur, SERR_ACCTHRUST, DISCONN)
    end
    ur = user.new(connid, user.US_LOGIN, acc, rl)
    switch_status(ur, user.US_WAIT_SELECT)

    userpool.add_byconnid(connid, ur)
    userpool.add_byacc(acc, ur)

    ur:send(IDUM_ROLELIST, {roles=rl})
    shaco.trace(sfmt("user %s login ok", acc)) 
end

REQ[IDUM_CREATEROLE] = function(ur, v)
    shaco.trace(sfmt("user %s create role %s...", ur.acc, v.name))
    if check_status(ur, user.US_WAIT_SELECT) then
        return
    end
    local rl = ur.roles
    if #rl >= 3 then
        return SERR_TOMUCHROLE
    end
    local name = v.name
    -- todo check name
    if #name <= 0 then
        return SERR_NAMEINVALID
    end
    local err = rcall(CTX.db, "C.name", name)
    if err == 0 then 
        local tp = tprole[v.tpltid]
        if not tp then
            return SERR_ROLETP
        end
        local base = role_base_gen(name, v.tpltid, tp)
        tinsert(rl, base)

        local roleid = rcall(CTX.db, "I.role", 
            {acc=ur.acc, name=name, base=pb.encode("role_base", base)})
        if roleid <= 0 then
            logout(ur, SERR_DB, DISCONN)
            return
        end
        base.roleid = tonumber(roleid)
        ur:send(IDUM_ROLELIST, {roles=rl})
        switch_status(ur, user.US_WAIT_SELECT)
		ur:create_log(roleid)
        shaco.trace(sfmt("user %s create role ok", ur.acc))
    elseif err == 1 then
        return SERR_NAMEEXIST
    else
        logout(ur, SERR_DB, DISCONN)
    end
end

REQ[IDUM_SELECTROLE] = function(ur, v)
    shaco.trace(sfmt("user %s select role index=%d...", ur.acc, v.index))
    if check_status(ur, user.US_WAIT_SELECT) then
        return
    end
    local rl = ur.roles
    if #rl == 0 then
        return SERR_NOROLE
    end
    local index = v.index+1
    if index<1 or index>#rl then
        return
    end
    local base = rl[index]
    assert(base)
    ur.base = base
    local info = rcall(CTX.db, "L.role", base.roleid)
    if info then
        info = pb.decode("role_info", info)
    end 
    local item = rcall(CTX.db, "L.ex", {roleid=base.roleid, name="item"})
    if item then
        item = pb.decode("item_list", item)
    end
	local task = rcall(CTX.db, "L.ex", {roleid=base.roleid, name="task"})
    if task then
        task = pb.decode("task_list", task).list
    end
    local card = rcall(CTX.db, "L.ex", {roleid=base.roleid, name="card"})
    if card then
        card = pb.decode("card_list", card).list
    end
	local club= rcall(CTX.db, "L.ex", {roleid=base.roleid, name="club_info"})
    if club then
        club = pb.decode("club_data", club).data
    end
	local mail= rcall(CTX.db, "L.ex", {roleid=base.roleid, name="mail"})
    if mail then
        mail = pb.decode("mail_list", mail)
    end
    ur:init(info, item, task, card,club,mail)

    switch_status(ur, user.US_GAME)

    userpool.add_byid(base.roleid, ur)
    userpool.add_byname(base.name, ur)
	ur:log_in_out_log(1)
    ur:entergame()
   
    shaco.trace(sfmt("user %s select %s enter game", ur.acc, base.name))
end

REQ[IDUM_EXITGAME] = function(ur, v)
    logout(ur, SERR_OK, DISCONN)
	
end

REQ[IDUM_NETDISCONN] = function(ur, v)
    logout(ur, SERR_OK, NODISCONN)
end

return REQ
