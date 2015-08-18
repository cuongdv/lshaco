--local shaco = require "shaco"
local shaco = require "shaco"
local pb = require "protobuf"
local tbl = require "tbl"
local sfmt = string.format
local ipairs = ipairs
local pairs = pairs
local tonumber = tonumber
local tostring = tostring

local partner = {}

local function partner_gen()
	return {
		pos = 0,
	}
end

function partner.new(size,partners)
	local flag = 0
    local partnerv = {}
    local idx = 1
    for k, v in ipairs(partners) do
        if v.pos == 0 then
            --shaco.warning("partners pos zero")
        else
            if partnerv[idx] then
                shaco.warning("pos repeat")
           	else
                partnerv[idx] = v
            end
            idx = idx + 1 
        end
    end
    for i = 1, size do
    	if not partnerv[i] then
    		partnerv[i] = partner_gen()
    	end
    end
    return partnerv
end

return partner
