-------------------interface---------------------
--function task_check_state(task, task_type, parameter1, parameter2)
--function task_accept(task,id)
-------------------------------------------------
local shaco = require "shaco"
local tptask = require "__tptask"
local bit32 = require"bit32"
local tbl = require "tbl"
local ipairs = ipairs
local sfmt = string.format
local sfind = string.find
local sub = string.sub
local len = string.len
local floor = math.floor
local task_fast = {}
--math.randomseed(os.time())
local daily_list = {}
local daily_update = 0

local function Split(szFullString, szSeparator)
	local nFindStartIndex = 1
	local nSplitIndex = 1
	local nSplitArray = {}
	while true do
		local nFindLastIndex = string.find(szFullString, szSeparator, nFindStartIndex)
		if not nFindLastIndex then
			nSplitArray[nSplitIndex] = string.sub(szFullString, nFindStartIndex, string.len(szFullString))
			break
		end
		nSplitArray[nSplitIndex] = string.sub(szFullString, nFindStartIndex, nFindLastIndex - 1)
		nFindStartIndex = nFindLastIndex + string.len(szSeparator)
		nSplitIndex = nSplitIndex + 1
	end
	return nSplitArray
end

local function init_daily_task()
	local task_list = {}
	for k, v in pairs(tptask) do
		if v.type == DAILY_TASK then
			task_list[#task_list + 1] = k
		end 
	end
	daily_list = {}
	daily_list[#daily_list + 1] = shaco.now()//1000
	local idx = 1
	while( idx < 1000 )
	do
		idx = idx + 1
		local index = math.random(#task_list)
		local flag = 0
		for j = 1,#daily_list do
			if task_list[index] == daily_list[j] then
				flag = 1
				break
			end
		end
		if flag == 0 then
			daily_list[#daily_list + 1] = task_list[index]
		end
		if #task_list == #daily_list then
			break
		end
		if #daily_list >= 11 then
			break
		end
	end
	local string_daily = ""
	for i =1,#daily_list do
		string_daily = string_daily..daily_list[i]..";"
	end
	return string_daily
end

function task_fast.init()
	local f = io.open(".task.tmp", "a+")
	local string_list = f:read("*all")
	if string_list == "" then
		local string_daily = init_daily_task()
		f:write(tostring(string_daily))
	else
		local result = Split(string_list,";")
		for i =1,#result do
			if result[i] ~= "" then
				daily_list[#daily_list + 1] = tonumber(result[i])
			end
		end
		local now_day = shaco.now()//1000//86400
		local last_day = daily_list[1]//86400
		if now_day ~= last_day then
			local string_daily = init_daily_task()
			f:write(tostring(string_daily))
		end
	end
	daily_update = 1
	f:close()
end

function task_fast.update(now)
	if daily_update ==1 then
		local now_day = floor((now/1000)/86400)
		
		local last_day = floor(daily_list[1]/86400)
		if now_day ~= last_day then
		
			local f = io.open(".task.tmp", "w")
			local string_daily = init_daily_task()
			f:write(tostring(string_daily))
			f:close()
		end
	end
end

function task_fast.update_daliy(ur)
	local task_list ={}
	local refresh_time = ur.info.refresh_time
	if refresh_time == 0 then
		for i =1,#daily_list do
			if i ~= 1 then
				task_list[#task_list + 1] = daily_list[i]
			end
		end
		--ur.info.refresh_time = daily_list[1]
		return true,task_list
	else
		local now_day = shaco.now()//86400
		local last_day = daily_list[1]//86400
		if now_day == last_day then
			return false,task_list
		else
			for i =1,#daily_list do
				if i ~= 1 then
					task_list[#task_list + 1] = daily_list[i]
				end
			end
			--ur.info.refresh_time = daily_list[1]
			return true,task_list
		end
	end
end

return task_fast
