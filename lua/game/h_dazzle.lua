--local shaco = require "shaco"
local shaco = require "shaco"
local pb = require "protobuf"
local tbl = require "tbl"
local sfmt = string.format
local ipairs = ipairs
local pairs = pairs
local tonumber = tonumber
local tostring = tostring
local tpdazzle_fragment = require "__tpdazzle_fragment"
local tpdazzle = require "__tpdazzle"
local dazzles = require "dazzle"
local itemop = require "itemop"
local task = require "task"
local REQ = {}

local function dazzle_fragment_gen()
	return {
		fragmentid = 0,
	}
end

REQ[IDUM_EQUIPDAZZLEFRAGMENT] = function(ur, v)
    local tp = tpdazzle_fragment[v.fragmentid]
	if not tp then
		return 
	end
	local dazzle = dazzles.get_dazzle(ur,v.dazzle_type,v.dazzle_level)
	if not dazzle then
		return SERR_DAZZLE_NOT_EXSIT
	end
	if tp.type ~= v.dazzle_type then
		return SERR_TYPE_NOT_SAME
	end
	--[[if #dazzle.dazzle_fragment == 0 then
		dazzle.dazzle_fragment = {}
	end
	dazzle.dazzle_fragment[#dazzle.dazzle_fragment + 1] = v.fragmentid]]
	dazzle.fragment = dazzle.fragment or {}
	local falg = false
	for i =1, #dazzle.fragment do
		if dazzle.fragment[i].fragmentid == 0 then
			local fragment_gen = dazzle_fragment_gen()
			fragment_gen.fragmentid = v.fragmentid
			dazzle.fragment[i] = fragment_gen
			falg = true
			break
		end
	end
	if falg == false  then
		local fragment_gen = dazzle_fragment_gen()
		fragment_gen.fragmentid = v.fragmentid
		dazzle.fragment[#dazzle.fragment + 1] = fragment_gen
	end
	itemop.take(ur, v.fragmentid, 1)
	itemop.refresh(ur)
	if dazzle.dazzle_use == 1then
		ur:change_attribute(ur)
	end
	ur:db_tagdirty(ur.DB_ROLE)
	ur:db_tagdirty(ur.DB_ITEM)
	ur:send(IDUM_HANDLEDAZZLERESULT, {success_type = EQUIP_FRAGEMENT,info = dazzle})
end

local function check_all_dazzle_level(ur)
	local dazzles = ur.info.dazzles
	local cnt = 0
	for i =1,#dazzles do
		if dazzles[i].dazzle_level >= 1 then
			cnt = cnt + 1
		end
	end
	return cnt
end

REQ[IDUM_COMPOSEDAZZLE] = function(ur, v)
	local dazzle = dazzles.get_dazzle(ur,v.dazzle_type,v.dazzle_level)
	if not dazzle then
		return SERR_DAZZLE_NOT_EXSIT
	end
	local next_dazzle = {}
	local level = dazzle.dazzle_level
	if dazzle.dazzle_have == 1 then
		next_dazzle = dazzles.get_next_dazzle(ur,v.dazzle_type,v.dazzle_level + 1)
		if not next_dazzle then
			return SERR_DAZZLE_NOT_EXSIT
		end
		level = next_dazzle.Level
	else
		dazzle.dazzle_have = 1
	end
	if #dazzle.fragment ~= 4 then
		return SERR_MATERIAL_NOT_ENOUGH
	end
	for i =1,#dazzle.fragment do
		--itemop.take(ur, dazzle.dazzle_fragment[i], 1)
		dazzle.fragment[i].fragmentid = 0
	end
	dazzle.dazzle_level = level
	task.set_task_progress(ur,38,level,0)
	task.refresh_toclient(ur, 38)
	local dazzle_cnt = check_all_dazzle_level(ur)
	if dazzle_cnt >= 5 then
		task.set_task_progress(ur,39,1,0)
		task.refresh_toclient(ur, 39)
	end
	ur:db_tagdirty(ur.DB_ROLE)
	if dazzle.dazzle_use == 1 then
		ur:change_attribute(ur)
	end
	ur:send(IDUM_HANDLEDAZZLERESULT, {success_type = DAZZLE_COMPOSE,info = dazzle})
end

REQ[IDUM_COMPOSEFRAGMENT] = function(ur, v)
	local dazzle = dazzles.get_dazzle(ur,v.dazzle_type,v.dazzle_level)
	if not dazzle then
		return SERR_DAZZLE_NOT_EXSIT
	end
	 local tp = tpdazzle_fragment[v.fragmentid]
	if not tp then
		return 
	end
	local bag = ur:getbag(BAG_PACKAGE)
    if not bag then
        return SERR_TYPE_ERROR
    end
	if not itemop.enough(ur, tp.Before_dazzle, tp.Dazzle_num2) then
		return SERR_MATERIAL_NOT_ENOUGH
	end	
	itemop.take(ur, tp.Before_dazzle, tp.Dazzle_num2)
	local flag = false
	for i = 1,#dazzle.fragment do
		if dazzle.fragment[i].fragmentid == 0 then
			dazzle.fragment[i].fragmentid = v.fragmentid
			flag = true
			break
		end
	end
	if flag == false and #dazzle.fragment < 4 then
		local fragment_gen = dazzle_fragment_gen()
		fragment_gen.fragmentid = v.fragmentid
		dazzle.fragment[#dazzle.fragment + 1] = fragment_gen
	end
	itemop.refresh(ur)
	ur:db_tagdirty(ur.DB_ROLE)
	ur:db_tagdirty(ur.DB_ITEM)	
	if dazzle.dazzle_use == 1 then
		ur:change_attribute(ur)
	end
	ur:send(IDUM_HANDLEDAZZLERESULT, {success_type = FRAGEMENT_COMPOSE,info = dazzle})
end

REQ[IDUM_USEDAZZLE] = function(ur, v)
	dazzles.clear_use(ur)
	local dazzle = dazzles.get_dazzle(ur,v.dazzle_type,v.dazzle_level)
	dazzle.dazzle_use = 1
	ur:change_attribute(ur)
	task.set_task_progress(ur,13,1,0)
	task.refresh_toclient(ur, 13)
	ur:send(IDUM_HANDLEDAZZLERESULT, {success_type = USE_DAZZLE,info = dazzle})
	ur:db_tagdirty(ur.DB_ROLE)
end

return REQ

