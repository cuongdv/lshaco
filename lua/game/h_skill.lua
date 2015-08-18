local shaco = require "shaco"
local tpskill = require "__tpskill"
local tostring = tostring
local sfmt = string.format
local skills = require"skill"
local tbl = require "tbl"
local tppassiveskill = require "__tppassiveskill"
local itemop = require "itemop"
local task = require "task"
local REQ = {}

REQ[IDUM_UPSKILL] = function(ur, v)
	local tp = {}
	if v.skillid > 0 then
		tp = tpskill[v.skillid]
	else
		local __gift = {}
		local gift_tp = tppassiveskill[v.skill_idx]
		if gift_tp then
			for j = 1,#gift_tp do
				local u = gift_tp[j]
				if u.skill_idx == v.skill_idx and u.type == v.gift_type and u.level == v.level then
					tp = u
					break
				end
			end
		end
	end
	if not tp then
		return SERR_ERROR_LABEL
	end
	local level = ur.base.level
	if level < tp.levellimit then
		return SERR_SKILL_UNLOCK
	end
	if ur:coin_enough(tp.gold) == false then
		return SERR_COIN_NOT_ENOUGH
	end
	local item1_flag = false
	local item2_flag = false 
	if tp.item_num > 0 then
		if itemop.enough(ur, tp.item, tp.item_num) == true then
			item1_flag = true
		else
			item1_flag = false
		end
	else
		item1_flag = true
	end
	if tp.item2_num > 0 then
		if itemop.enough(ur, tp.item2, tp.item2_num) == true then
			item2_flag = true
		else
			item2_flag = false
		end
	else
		item2_flag = true
	end
	if item1_flag == true and item2_flag == true then
		itemop.take(ur, tp.item, tp.item_num)
		itemop.take(ur, tp.item2, tp.item2_num)
	else
		return SERR_MATERIAL_NOT_ENOUGH
	end
	ur:coin_got(tp.gold)
	local skillv = {}
	local skill = ur.info.skills
	if v.skillid > 0 then
		for i = 1,#skill do
			local __tp = tpskill[skill[i].skill_id]
			if __tp.skill_idx == tp.skill_idx and __tp.level + 1 == tp.level then
				skill[i].skill_id = v.skillid
				break
			end
		end
		task.set_task_progress(ur,47,tp.level,0)
		task.refresh_toclient(ur, 47)
	else
		local  flag = false 
		for i = 1,#skill do
			if flag == true then
				break
			end
			for j =1,#skill[i].gift do
				local gift_info = skill[i].gift[j] 
				if gift_info.skill_idx == v.skill_idx and gift_info.__type == v.gift_type and gift_info.level == v.level -1 then
					gift_info.level = gift_info.level + 1
					break
				end
			end
		end
	end
	ur:db_tagdirty(ur.DB_ROLE)
	itemop.refresh(ur)
	ur:db_tagdirty(ur.DB_ITEM)
	ur:send(IDUM_UPDATESKILL, {success = 1})
end

return REQ
