local shaco = require "shaco"
local tbl = require "tbl"
local CTX = require "ctx"
local pb = require "protobuf"
local tbl = require "tbl"
local ipairs = ipairs

local ectype_fast = {}
local record = {}
local dirty_flag = {}

function ectype_fast.init()
end

function ectype_fast.load(all)
    record = {}
    for _, v in ipairs(all) do
        local one = pb.decode("ectype_fast", v.data)
        record[one.ectype_id] = one
    end 
end

local function _gen(id, ur, value, now)
    local name = ur.base.name
    return {
        ectype_id=id,
        first_role_guild=nil,
        first_role_name=name,
        first_value=now,
        fast_role_guild=nil,
        fast_role_name=name,
        fast_value=value,
		star=0,
    }
end

local function _tagdirty(id)
    for _, v in ipairs(dirty_flag) do
        if v == id then
            return
        end
    end
    dirty_flag[#dirty_flag+1] = id
end

function ectype_fast.try_replace(id, ur, time)
    local et = record[id]
    local dirty = false
    if et == nil then
        record[id] = _gen(id, ur, time, shaco.now()//1000)
        dirty = true
    else
        if et.fast_value < time then
            et.fast_value = time 
            if et.fast_role_name ~= ur.base.name then
                et.fast_role_name = ur.base.name
            end
            dirty=true
        end
    end
    if dirty then
        _tagdirty(id)
        return true
    end
    return false
end

function ectype_fast.db_flush()
    if #dirty_flag == 0 then
        return
    end
    for _, id in ipairs(dirty_flag) do
        local et = record[id]
        assert(et)
        shaco.send(CTX.db, shaco.pack("S.global", {
            name="ectype_fast", id=id, data=pb.encode("ectype_fast", et) }))
    end
    dirty_flag = {}
end

function ectype_fast.handle(ur, type, data)
    -- todo handle user info change
end

function ectype_fast.query(id)
    return record[id]
end

return ectype_fast
