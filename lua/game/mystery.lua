--local shaco = require "shaco"
local shaco = require "shaco"
local pb = require "protobuf"
local tbl = require "tbl"
local sfmt = string.format
local floor = math.floor
local ipairs = ipairs
local pairs = pairs
local tonumber = tonumber
local tostring = tostring
local tpmystery_shop = require "__tpmystery_shop"

local mystery = {}

local function mystery_gen()
	return {
		start_time = 0,
		info = {},
		refresh_cnt = 0,
	}
end

local function mystery_item_gen()
	return {
		itemid = 0,
		itemcnt = 0,
		pos = 0,
		falg = 0,
	}
end

local function random_mystery_item(shop_info)
	local item_list = {}
	for i = 1,12 do
		local total_weight = 0
		if #shop_info["position"..tostring(i).."_item"] >0 then
			for j =1,#shop_info["position"..tostring(i).."_item"] do
				total_weight = total_weight + shop_info["position"..tostring(i).."_item"][j].weighing
			end
			local random_value = math.random(1,total_weight)
			local weight = 0
		
			for j =1,#shop_info["position"..tostring(i).."_item"] do
				weight = weight + shop_info["position"..tostring(i).."_item"][j].weighing
				if weight >= random_value then
					local item_info = mystery_item_gen()
					item_info.itemid = shop_info["position"..tostring(i).."_item"][j].item_id
					item_info.itemcnt = shop_info["position"..tostring(i).."_item"][j].count
					item_info.pos = i
					item_info.falg = 0
					item_list[#item_list + 1] = item_info
					break
				end
			end
		end
	end
	return item_list
end

local function random_item(ur)
	local level = ur.base.level
	local mystery_list = {}
	local total_weight = 0
	for k,v in pairs(tpmystery_shop) do
		if v.user_level[1][1] <= level and v.user_level[1][2] >= level then
			mystery_list[#mystery_list + 1] = v
			total_weight = total_weight + v.weight
		end
	end
	local weight = 0
	local mystery_info = {}
	local random_weight = math.random(1,total_weight)
	for i =1,#mystery_list do
		weight = weight + mystery_list[i].weight
		if weight >= random_weight then
			mystery_info = random_mystery_item(mystery_list[i])
			break
		end
	end
	return mystery_info
	
end

function mystery.random_mystery_shop(ur,probability)
	local rand_value = math.random(1,100)
	if rand_value < probability then
		local mystery_info = mystery_gen()
		mystery_info.start_time = shaco.now()//1000
		mystery_info.info = random_item(ur)
		ur.info.mystery = nil
		ur.info.mystery = mystery_info
		--tbl.print(mystery_info.info, "=============init mystery_info.info", shaco.trace)
		ur:send(IDUM_NOTICEMYSTERYSHOP, {info = mystery_info,start_time = mystery_info.start_time})
	end
end

function mystery.refresh_mystery_shop(ur)
	local item_list = {}
	item_list = random_item(ur)
	ur.info.mystery.refresh_cnt = ur.info.mystery.refresh_cnt + 1
	ur.info.mystery.info = item_list
	ur:send(IDUM_ACKREFRESHMYSTERYRESULT, {info = item_list,refresh_cnt = ur.info.mystery.refresh_cnt})
end

return mystery
