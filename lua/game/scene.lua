local shaco = require "shaco"
local tbl = require "tbl"
local tpscene = require "__tpscene"
local sfmt = string.format
local uid_scenes = {}
local tpid_scenes = {}
local uid_alloc = 0
local scene = {}

local function is_city(tp)
    return tp.type == SCENE_CITY
end

local function scene_single(tp)
    return tp.type ~= SCENE_CITY and
           tp.type ~= SCENE_BOSS
end

local function scene_gen(uid, tpid)
    return {
        __uid = uid,
        __tpid = tpid,
        __objs = {},
        __chanid = nil
    }
end

local function scene_obj_gen(obj)
    return {
        name = obj.base.name,
        tpltid = obj.base.tpltid,
        oid = obj.info.oid,
        posx = obj.info.posx,
        posy = obj.info.posy,
    }
end

local function test_scene_obj_gen()
    return {
        name = "12345622qq",
        tpltid = 1,
        oid = 10100,
        posx = 300,
        posy = 100,
    }
end
function scene.enter(obj, tpid)
    local tp = tpscene[tpid]
    if not tp then
        shaco.warning(sfmt("scene %u not found", tpid))
        return
    end
    local s = tpid_scenes[tpid]
    if s == nil then
        uid_alloc = uid_alloc + 1
        while uid_scenes[uid_alloc] ~= nil do
            uid_alloc = uid_alloc + 1
        end
        s = scene_gen(uid_alloc, tpid)
        if scene_single(tp) then
            s.__chanid = nil
        else
            s.__chanid = "S"..uid_alloc
        end
        uid_scenes[uid_alloc] = s
        tpid_scenes[tpid] = s
    end
    if obj.scene then
        --if obj.scene == s then
            --return
        --else
            scene.exit(obj)
        --end
    end
    local oid = obj.info.oid 
    assert(s.__objs[oid] == nil)

    if is_city(tp) then
        obj.info.last_city = tpid
    end
    obj.info.mapid = tpid
    obj.info.posx = tp.reviveX
    obj.info.posy = tp.reviveY
    obj.scene = s
    shaco.trace(sfmt("scene %u:%u enter obj %u", tpid, s.__uid, oid))

    obj:send(IDUM_SCENECHANGE, {mapid=tpid, 
        posx=obj.info.posx, posy=obj.info.posy})
    if s.__chanid then
        for _, o in pairs(s.__objs) do
            local so = scene_obj_gen(o)
            obj:send(IDUM_OBJECTAPPEAR, {info=so})
        end
        local so = scene_obj_gen(obj)
        obj:chan_publish(s.__chanid, IDUM_OBJECTAPPEAR, {info=so})
        obj:chan_subscribe(s.__chanid)
    end 
    s.__objs[oid] = obj 
    return true
end

function scene.addrobot(ur,cnt)
	for i =1,cnt do
		local so = test_scene_obj_gen()
		so.oid = so.oid + i
		so.posx = so.posx + math.random(0,200)
		so.posy = so.posy + math.random(0,200)
		so.name = so.name..tostring(i)
		ur:send(IDUM_OBJECTAPPEAR, {info=so})
	end
end


function scene.exit(obj)
    local s = obj.scene
    assert(s ~= nil)
    local oid = obj.info.oid
    assert(s.__objs[oid] == obj)     
    s.__objs[oid] = nil
    obj.scene = nil
    shaco.trace(sfmt("scene %u:%u exit obj %u", s.__tpid, s.__uid, oid))

    if s.__chanid then
        local v = {oid=oid}
        for _, o in pairs(s.__objs) do
            obj:send(IDUM_OBJECTDISAPPEAR, v)
        end 
        obj:chan_publish(s.__chanid, IDUM_OBJECTDISAPPEAR, v)
        obj:chan_unsubscribe(s.__chanid)
    end
end

function scene.move(obj, v)
    local s = obj.scene
    if not s then
        return
    end
    local oid = obj.info.oid
    obj.info.posx = v.posx
    obj.info.posy = v.posy
    local v = {
        oid = oid,
        posx = v.posx,
        posy = v.posy,
        speed = v.speed,
        dirx = v.dirx,
        diry = v.diry,
    }
    shaco.trace(sfmt("scene %u:%u move obj %u", s.__tpid, s.__uid, oid))

    if s.__chanid then
        obj:chan_publish(s.__chanid, IDUM_MOVESYNC, v)
    else
        obj:send(IDUM_MOVESYNC, v)
    end
end

function scene.movestop(obj, v)
    local s = obj.scene
    if not s then
        return
    end
    local oid = obj.info.oid
    obj.info.posx = v.posx
    obj.info.posy = v.posy
    local v = {
        oid = oid,
        posx = v.posx,
        posy = v.posy,
    }
    shaco.trace(sfmt("scene %u:%u movestop obj %u", s.__tpid, s.__uid, oid))
    if s.__chanid then
        obj:chan_publish(s.__chanid, IDUM_MOVESTOPSYNC, v)
    else
        obj:send(IDUM_MOVESTOPSYNC, v)
    end
end

return scene
