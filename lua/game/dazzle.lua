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
local tpdazzle = require "__tpdazzle"
local dazzles = {}

local function dazzle_gen()
	return {
		dazzle_type = 0,
		dazzle_level=0,
		fragment = {},
		dazzle_use =0,
		dazzle_have=0,
	}
end

local function create_dazzle()
	local dazzle_list = {}
	for i =1,5 do
		for k, v in pairs(tpdazzle) do
			if v.Type == i and v.Level == 1 then
				local dazzle = dazzle_gen()
				dazzle.dazzle_type = v.Type
				dazzle.dazzle_level = v.Level
				dazzle_list[#dazzle_list + 1] = dazzle
				break
			end
		end
	end
	return dazzle_list
end

function dazzles.new(dazzlev) 
    local dazzles = {}
    local idx = 1
    for k, v in ipairs(dazzlev) do
        if v.dazzle_type == 0 then
            shaco.warning("dazzle dazzle_type zero")
        else
            if dazzles[idx] then
                shaco.warning("dazzle_type repeat")
           	else
                dazzles[idx] = v
            end
            idx = idx + 1 
        end
    end
	if #dazzles == 0 then
    	dazzles = create_dazzle()
    end
    return dazzles
end

function dazzles.get_dazzle(ur,dazzle_type,dazzle_level)
	local dazzles = ur.info.dazzles
	for i =1,#dazzles do
		local dazzle = dazzles[i]
		if dazzle.dazzle_type == dazzle_type and dazzle.dazzle_level == dazzle_level then
			return dazzle
		end
	end
end

function dazzles.get_next_dazzle(ur,dazzle_type,dazzle_level)
	for k, v in pairs(tpdazzle) do
		if v.Type == dazzle_type and v.Level == dazzle_level then
			return v
		end
	end
end

function dazzles.clear_use(ur)
	local dazzles = ur.info.dazzles
	for i =1,#dazzles do
		local dazzle = dazzles[i]
		if dazzle.dazzle_use == 1  then
			dazzle.dazzle_use = 0
		end
	end
end

return dazzles
