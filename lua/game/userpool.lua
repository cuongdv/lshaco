local shaco = require "shaco"
local user = require "user"
local floor = math.floor

-- user container
local conn2user = {}
local acc2user = {}
local oid2user = {} -- US_GAME state
local name2user = {} -- US_GAME state

local userpool = {}

function userpool.find_byconnid(connid)
    return conn2user[connid]
end

function userpool.find_byid(roleid)
    return oid2user[roleid]
end
function userpool.find_byacc(acc)
    return acc2user[acc]
end

function userpool.isgaming(ur)
    return ur.status == user.US_GAME
end

function userpool.add_byconnid(connid, ur)
    conn2user[connid] = ur
end

function userpool.add_byacc(acc, ur)
    acc2user[acc] = ur
end

function userpool.add_byname(name, ur)
    name2user[name] = ur
end

function userpool.add_byid(roleid, ur)
    oid2user[roleid] = ur
end

function userpool.logout(ur)
    if ur.status > user.US_LOGIN then
        conn2user[ur.connid] = nil
        acc2user[ur.acc] = nil
    end
    if ur.status > user.US_WAIT_SELECT then
        oid2user[ur.base.roleid] = nil
        name2user[ur.base.name] = nil
    end
end

local day_msec = 86400000
local last_day = shaco.now()//day_msec

function userpool.foreach(now)
    local now_day  = floor(now/day_msec)
    for _, ur in pairs(oid2user) do
        if now_day ~= last_day then
            ur:onchangeday()
            last_day = now_day
        end
        ur:ontime(now)
    end
end

return userpool
