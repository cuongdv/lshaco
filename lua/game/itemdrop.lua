--local shaco = require "shaco"
local shaco = require "shaco"
local pb = require "protobuf"
local tbl = require "tbl"
local sfmt = string.format
local ipairs = ipairs
local pairs = pairs
local tonumber = tonumber
local tostring = tostring
local tpmonster = require "__tpmonster" 
local tpitemdrop = require "__tpitemdrop"
local tpscene = require "__tpscene"
local BASE_VALUE = 100000 
local itemdrop = {}

local function item_list_gen()
	return {
		itemid = 0,
		cnt = 0,
	}
end

local function turn_card_gen()
	return {
		itemid = 0,
		cnt = 0,
		type = 0,
	}
end

function itemdrop.random_drop_item(rewards)
	local item_list = {}
	local total_weight = 0
	for i =1,#rewards do
		total_weight = total_weight + rewards[i][3]
	end
	local random_weight = math.random(0,total_weight)
	local weight = 0
	for i =1,#rewards do
		weight = weight + rewards[i][3]
		if weight >= random_weight then
			item_list[#item_list+1] = item_list_gen()
			item_list[#item_list].itemid = rewards[i][1]
			item_list[#item_list].cnt = rewards[i][2]
			break
		end
	end
	
	return item_list
end

local function turn_card_reward_gen()
	return {
		itemid = 0,
		cnt = 0,
		__type = 0,
	}
end

function itemdrop.compute_copy_result(ur,copyid)
	local tp = tpscene[copyid]
	if not tp then
		return
	end
	local turn_list = {}
	local turn_card_list = {}
	turn_list = itemdrop.random_drop_item(tp.items1)
	if not turn_list then
		return SERR_ERROR_LABEL
	end
	turn_card_list[#turn_card_list + 1] = turn_card_gen()
	turn_card_list[#turn_card_list].itemid = turn_list[1].itemid
	turn_card_list[#turn_card_list].cnt = turn_list[1].cnt
	turn_card_list[#turn_card_list].type = UN_GOLD_TURN
	turn_list = itemdrop.random_drop_item(tp.items2)
	if not turn_list then
		return SERR_ERROR_LABEL
	end
	if #turn_list > 0 then
		turn_card_list[#turn_card_list + 1] = turn_card_gen()
		turn_card_list[#turn_card_list].itemid = turn_list[1].itemid
		turn_card_list[#turn_card_list].cnt = turn_list[1].cnt
		turn_card_list[#turn_card_list].type = GOLD_TURN
		ur.turn_card_reward = turn_card_list
	end
	ur:send(IDUM_TURNCARDRESULT, {info = turn_card_list})
end

return itemdrop
