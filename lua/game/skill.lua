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
local tprole = require "__tpcreaterole" 
local tppassiveskill = require "__tppassiveskill"

local skills = {}

local function gift_gen()
	return{
		skill_idx=0,
		__type =0,
		level=0,
	}
end

local function skills_gen()
	return {
		skill_id = 0,
		gift = {},
	}
end

local function save_skill(tpltid)
	local skill_list = {}
	local tp = tprole[tpltid]
	if not tp then
		return
	end
	for i =1,3 do
		local skill = skills_gen()
		skill.skill_id = tp["skill"..i]
		
		local gift_index,decimals = math.modf(skill.skill_id/1000)
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
		skill.gift = __gift
		skill_list[#skill_list + 1] = skill
	end
	return skill_list
end

function skills.new(tpltid,skillv)
	local flag = 0
    local skill = {}
    local idx = 1
    for k, v in ipairs(skillv) do
        if v.skill_id == 0 then
            shaco.warning("skillv skill_id zero")
        else
            if skill[idx] then
                shaco.warning("skill_id repeat")
           	else
                skill[idx] = v
            end
            idx = idx + 1 
        end
    end
    if #skill == 0 then
    	skill = save_skill(tpltid)
    	flag = 1
    end
    return skill,flag
end

return skills
