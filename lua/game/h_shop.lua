--local shaco = require "shaco"
local shaco = require "shaco"
local pb = require "protobuf"
local tbl = require "tbl"
local sfmt = string.format
local ipairs = ipairs
local pairs = pairs
local tonumber = tonumber
local tostring = tostring
local tpcardrandom = require "__tpcardrandom"
local tpcardwarehouse = require "__tpcardwarehouse"
local tpcard = require "__tpcard"
local tpgamedata = require "__tpgamedata"
local card_container = require "card_container"
local task = require "task"

local REQ = {}
local function random_cards(tp)
	local totalvalue = 0
	for i = 1,10 do
		totalvalue = totalvalue + tp["CardProportion"..i]
	end
	local randvalue = math.random(1,totalvalue)
	local randomsum = 0
	for i = 1,10 do
		randomsum = randomsum + tp["CardProportion"..i]
		if randomsum >= randvalue then
			return i
		end
	end
	return 0
end

local function random_card(random_list)
	local allvalue = 0
	for i=1,#random_list do
		allvalue = allvalue + random_list[i].Proportion
	end
	local rand_value = math.random(1,allvalue)
	local random_sum = 0
	for i = 1,#random_list do
		random_sum = random_sum + random_list[i].Proportion
		if random_sum >= rand_value then
			return random_list[i].CardID
		end
	end
	return 0
end

local function check_money_enough(ur,take,price_type)
	if price_type == 0 then
		if ur:coin_enough(take) == false then
			return false
		end 
	elseif price_type == 1 then
		if ur:gold_enough(take) == false then
			return false
		end
	end 	
	return true
end

local function cost_money(ur,take,price_type)
	if price_type == 0 then
		if ur:coin_take(take) == false then
			return false
		end 
	elseif price_type == 1 then
		if ur:gold_take(take) == false then
			return false
		end
	end 	
	return true
end

local function check_random_card(array,quality,compensation_random)
	local flag = 0
	for i = 1, #array do
		local tp = tpcard[array[i]]
		if not tp then
			return false
		end
		if tp.quality >= quality then
			flag = 1
			break 
		end
	end
	if flag == 0 then
		local random_list = {}
		for i = 1,#tpcardwarehouse do
			if tpcardwarehouse[i].ID == compensation_random then
				random_list[#random_list + 1] = tpcardwarehouse[i]
			end
		end
		local cardid = random_card(random_list)
		if cardid == 0 then
			return false
		end
		local rand_value = math.random(#array)
		if rand_value == 0 then
			rand_value = 1
		end
		array[rand_value] = cardid
	end
	return true
end

REQ[IDUM_SHOPBUYITEM] = function(ur, v)
	local tp = tpcardrandom[v.random_id]
	if not tp then
		return SERR_ERROR_LABEL
	end
	local indx = random_cards(tp)
	if indx == 0 then
		return SERR_ERROR_LABEL1
	end
	local random_list = {}
	for i = 1,#tpcardwarehouse do
		if tpcardwarehouse[i].ID == tp["CardStar"..indx] then
			random_list[#random_list + 1] = tpcardwarehouse[i]
		end
	end
	if v.buy_type == BUY_SINGLE then
		if cost_money(ur,tp.UnitPrice,tp.PriceType) == false then
			return SERR_COIN_NOT_ENOUGH
		end
	elseif v.buy_type == BUY_TEN then
		if cost_money(ur,tp.TenPrice,tp.PriceType) == false then
			return SERR_GOLD_NOT_ENOUGH
		end
	end
	local card_array = {}
	if v.buy_type == BUY_SINGLE then
		local cardid = random_card(random_list)
		if cardid == 0 then
			return SERR_ERROR_LABEL2
		end
		card_array[#card_array + 1] = cardid
	elseif v.buy_type == BUY_TEN then
		for i = 1,10 do
			indx = random_cards(tp)
			if indx == 0 then
				return SERR_ERROR_LABEL1
			end
			random_list = {}
			for i = 1,#tpcardwarehouse do
				if tpcardwarehouse[i].ID == tp["CardStar"..indx] then
					random_list[#random_list + 1] = tpcardwarehouse[i]
				end
			end
			local cardid = random_card(random_list)
			if cardid == 0 then
				return SERR_ERROR_LABEL2
			end
			card_array[#card_array + 1] = cardid
		end
	else
		return SERR_TYPE_ERROR
	end
	if tp.FPOpen == 1 and v.buy_type == BUY_TEN then
		if check_random_card(card_array,tp.TenType,tp.TenStart) == false then
			return SERR_ERROR_LABEL
		end
	end
	for i =1,#card_array do
		ur.cards:put(ur,card_array[i],1)
	end
	ur.cards.refresh(ur)
	ur:sync_role_data()
    ur:db_tagdirty(ur.DB_CARD)
	ur:card_log(v.buy_type,tp.PriceType,card_array)
	ur:db_tagdirty(ur.DB_ROLE)
	task.set_task_progress(ur,14,0,0)
	task.refresh_toclient(ur, 14)
	ur:send(IDUM_BUYCARDSUCCESS, {card_array = card_array})
end

REQ[IDUM_BUYCARDSUCCESS] = function(ur, v)
	local card_size = ur.info.cards_size
	local max_size = tpgamedata.CardBackpackMax
	if card_size >= max_size then
		return SERR_CARD_GRID_MAX
	end
	if ur:gold_take(tpgamedata.CardBackpackPrice) then
		return SERR_GOLD_NOT_ENOUGH
	end
	ur.info.cards_size = card_size + 10
	ur:sync_role_data()
	ur:db_tagdirty(ur.DB_ROLE)
	ur:send(UM_BUYCARDSIZERESULT,{card_grid_cnt = card_size})
end

return REQ