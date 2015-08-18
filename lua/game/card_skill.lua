--local shaco = require "shaco"
local shaco = require "shaco"
local pb = require "protobuf"
local tbl = require "tbl"
local sfmt = string.format
local ipairs = ipairs
local pairs = pairs
local tonumber = tonumber
local tostring = tostring
local tpskill = require "__tpskill"
local tpcard = require "__tpcard"
local tppassiveskill = require "__tppassiveskill"

local card_skill = {}

local function gift_gen()
	return{
		skill_idx=0,
		__type =0,
		level=0,
	}
end

local function card_skill_gen()
	return {
		skill_id = 0,
		gift = {}
	}
end

function card_skill.create_skill(cardid)
	local skill_list = {}
	local tp = tpcard[cardid]
	if not tp then
		return skill_list
	end
	local idx = 1
	for i =1,15 do
		local skill = tp["skill"..i]
		local skillv = {}
		if #skill == 3 then
			skillv = card_skill_gen()
			--skillv.unlock_level = skill[1]
			skillv.skill_id = skill[2]
			local gift_index,decimals = math.modf(skillv.skill_id/1000)
			local __gift = {}
			local gift_tp = tppassiveskill[gift_index]
			if gift_tp then
				for j = 1,#gift_tp do
					local v = gift_tp[j]
					if v.skill_idx == gift_index and v.level == 0 then
						local gift_info = gift_gen()
						gift_info.skill_idx = gift_index
						gift_info.__type = v.type
						gift_info.level = v.level
						__gift[#__gift + 1] = gift_info
					end
				end
			end
			skillv.gift = __gift
			skill_list[#skill_list + 1] = skillv
		end
	end
	return skill_list
end

return card_skill
