local shaco = require "shaco"
local pb = require "protobuf"
local tbl = require "tbl"
local sfmt = string.format
local floor = math.floor
local ipairs = ipairs
local tonumber = tonumber
local tostring = tostring
local tpscene = require "__tpscene"

local ectype = {}

local function pass_ectype_gen()
	return {
		ectypeid = 0,
		star = 0,
		pass=0,
		cur_time=0,
		pass_time=0,
		old_pass_time=0,
	}
end

function ectype.save_ectype(ur,ectypeid,new_star)
	local ectype_list = ur.info.ectype
	local cur_time = floor(shaco.now()//1000)
	local pass_time = cur_time - ur.info.map_entertime
	for i = 1,#ectype_list do
		local ectype_info = ectype_list[i]
		if ectype_info.ectypeid == ectypeid then
			if new_star > ectype_info.star then
				if ectype_info.star == 0 then
					ectype_info.pass = 1
				end
				ectype_info.star = new_star
				ectype_info.cur_time = cur_time
				ectype_info.old_pass_time = ectype_info.pass_time
				ectype_info.pass_time = pass_time
			end
			return 
		end
	end
	
	local ectype_gen = pass_ectype_gen()
	ectype_gen.ectypeid = ectypeid
	ectype_gen.star = new_star
	if new_star == 0 then
		ectype_info.pass = 0
	end
	ectype_list[#ectype_list + 1] = ectype_gen
end

function ectype.new(ectypev)
    local ectypes = {}
    local idx = 1
    for k, v in ipairs(ectypev) do
        if v.ectypeid == 0 then
            shaco.warning("ectypev ectypeid zero")
        else
        	local ectype = ectypes[idx] 
            if ectype then
                shaco.warning("ectypeid repeat")
           	else
                ectypes[idx] = v
            end
            idx = idx + 1 
        end
    end
    return ectypes
end

function ectype.open_all_ectype(ur)
	for k, v in ipairs(tpscene) do
		ectype.save_ectype(ur,k,1)
	end 
end

return ectype
