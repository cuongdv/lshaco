local shaco = require "shaco"
local tostring = tostring
local sfmt = string.format
local mystery = require "mystery"
local tbl = require "tbl"
local floor = math.floor
local tpmystery_shop = require "__tpmystery_shop"
local tppayprice = require "__tppayprice"
local itemop = require "itemop"
local REQ = {}

local function get_cost(itemid,cnt)
	for k,v in pairs(tpmystery_shop) do
		for i = 1,12 do
			for j =1,#v["position"..tostring(i).."_item"] do
				if v["position"..tostring(i).."_item"][j].item_id == itemid and v["position"..tostring(i).."_item"][j].count == cnt then
					return v["position"..tostring(i).."_item"][j].money,v["position"..tostring(i).."_item"][j].money_count
				end
			end
		end
	end
end

REQ[IDUM_REQBUYMYSTERYITEM] = function(ur, v)
	local mystery_info = ur.info.mystery
	local cur_time = shaco.now()//1000
	if cur_time - mystery_info.start_time > 500 then
		return SERR_MYSTERY_SHOP_TIME_OVER
	end
	local flag = false
	for i=1,#mystery_info.info do
		if mystery_info.info[i].itemid == v.itemid and mystery_info.info[i].pos == v.pos and mystery_info.info[i].falg == 0 and mystery_info.info[i].itemcnt == v.cnt then
			flag = true
			break
		end
	end
	if flag == false then
		return SERR_MYSTERY_SHOP_ITEM_NOT_EXSIT
	end
	
	local money_type,take = get_cost(v.itemid,v.cnt)
	if money_type == 0 then
		if ur:coin_take(take) == false then
			return SERR_COIN_NOT_ENOUGH
		end 
	elseif money_type == 1 then
		if ur:gold_take(take) == false then
			return SERR_GOLD_NOT_ENOUGH
		end
	end 	
	local pos = 0
	for i=1,#mystery_info.info do
		if mystery_info.info[i].itemid == v.itemid and mystery_info.info[i].itemcnt == v.cnt then--and  mystery_info.info[i].pos == v.pos then
			pos = mystery_info.info[i].pos
			mystery_info.info[i].falg = 1
			break
		end
	end
	itemop.gain(ur, v.itemid, v.cnt)
	itemop.refresh(ur)
	ur:sync_role_data()
	ur:db_tagdirty(ur.DB_ROLE)
	ur:db_tagdirty(ur.DB_ITEM)
	ur:send(IDUM_ACKBUYMYSTERYRESULT,{itemid = v.itemid,cnt = v.cnt,pos = pos})
end

REQ[IDUM_REQREFRESHMYSTERY] = function(ur, v)
	local cnt = ur.info.mystery.refresh_cnt + 1
	local take = 0
	local money_tpye = 0
	for k, u in ipairs(tppayprice) do
		if u.type == 1 and cnt >= u.start and cnt <= u.stop then
			take = u.number
			money_tpye = u.money_tpye
		end
	end
	if money_tpye == 0 then
		if ur:coin_take(take) == false then
			return SERR_COIN_NOT_ENOUGH
		end
	elseif money_tpye == 1 then
		if ur:gold_take(take) == false then
			return SERR_GOLD_NOT_ENOUGH
		end
	end
	mystery.refresh_mystery_shop(ur)
	ur:db_tagdirty(ur.DB_ROLE)
end

return REQ
