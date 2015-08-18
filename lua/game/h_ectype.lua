local shaco = require "shaco"
local pb = require "protobuf"
local tbl = require "tbl"
local sfmt = string.format
local ipairs = ipairs
local tonumber = tonumber
local tostring = tostring
local floor = math.floor
local ectype = require "ectype"
local ectype_fast = require "ectype_fast"
local task = require "task"
local tpscene = require "__tpscene"
local itemdrop = require "itemdrop"
local itemop = require "itemop"
local mystery = require "mystery"
local REQ = {}


local function compute_ectype_result(ur,ectypeid)
	local tp = tpscene[ectypeid]
	if not tp then
		return
	end
	ur:addexp(tp.exp)
	ur:sync_role_data()
end

REQ[IDUM_PASSECTYPE] = function(ur, v)
	local pass_star = 0
	if v.user_hp < 50 then
		pass_star = 1
	elseif v.user_hp >= 50 and v.user_hp < 90 then
		pass_star = 2
	elseif v.user_hp >= 90 then
		pass_star = 3
	end
	ectype.save_ectype(ur,v.ectypeid,pass_star)
    local pass_time = shaco.now()//1000-ur.info.map_entertime
    ectype_fast.try_replace(v.ectypeid, ur, pass_time)
    local recordv = ectype_fast.query(v.ectypeid)
	recordv.star = pass_star
	--ur:save_drop_item()
    ur:send(IDUM_COPYRECORD, {record = recordv})
	compute_ectype_result(ur,v.ectypeid)
	ur:db_tagdirty(ur.DB_ROLE)
	task.set_task_progress(ur,1,v.ectypeid,0)
	task.refresh_toclient(ur, 1)
	if pass_star  == 3 then
		task.set_task_progress(ur,2,v.ectypeid,0)
		task.refresh_toclient(ur, 2)
	end
    ectype_fast.db_flush()
	local tp = tpscene[v.ectypeid]
	if not tp then
		return SERR_ERROR_LABEL
	end
	if tp.mystery_shop > 0 then
		mystery.random_mystery_shop(ur,tp.mystery_shop)
	end
	if not ur.battle_verify then
		ur:x_log_role_cheat(v.ectypeid,0,0,0)
	end
end

REQ[IDUM_PASSECTYPEFAIL] = function(ur, v)
	ectype.save_ectype(ur,v.ectypeid,0)
end

REQ[IDUM_GETTURNCARDREWARD] = function(ur, v)
	--ur:get_turn_card_reward(v.turn_type)
	local itemid = 0
	for i = 1,#ur.turn_card_reward do
		if ur.turn_card_reward[i].type == v.turn_type then
			itemid = ur.turn_card_reward[i].itemid
			local idnums = {{itemid,ur.turn_card_reward[i].cnt}}
			if itemop.can_gain(ur, idnums) then
				itemop.gain(ur,itemid , ur.turn_card_reward[i].cnt)
			else
				return SERR_PACKAGE_SPACE_NOT_ENOUGH
			end
			break
		end
	end
	itemop.refresh(ur)
	ur:db_tagdirty(ur.DB_ITEM)
	ur:send(IDUM_GETTURNCARDRESULT, {itemid = itemid})
end

REQ[IDUM_GETDROPITEM] = function(ur, v)
	local idnums = {}
	for i =1,#v.info do
		local flag = false
		local count = 0
		for j= 1,#ur.item_drop do
			if ur.item_drop[j].itemid == v.info[i].itemid then
				count = count + ur.item_drop[j].cnt
				break
			end
		end
		if v.info[i].cnt <= count and count > 0 then
			idnums[#idnums + 1] = {v.info[i].itemid,v.info[i].cnt}
			flag = true
		end
		if flag == false then
			return SERR_DROP_ITEM_ERROR
		end
	end
	if itemop.can_gain(ur, idnums) then
	else
		return SERR_PACKAGE_SPACE_NOT_ENOUGH
	end
	for i =1,#idnums do
		itemop.gain(ur,idnums[i][1] , idnums[i][2])
	end
	if v.coin > ur.drop_coin then
		return SERR_DROP_COIN_ERROR
	end
	ur:coin_got(ur.drop_coin)
	ur.drop_coin = 0
	ur.item_drop = {}
	itemop.refresh(ur)
	ur:sync_role_data()
	ur:db_tagdirty(ur.DB_ITEM)
end

return REQ
