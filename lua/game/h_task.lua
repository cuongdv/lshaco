--local shaco = require "shaco"
local shaco = require "shaco"
local pb = require "protobuf"
local sfmt = string.format
local tptask = require "__tptask"
local ipairs = ipairs
local tonumber = tonumber
local tostring = tostring
local task = require "task"
local tbl = require "tbl"
local itemop = require "itemop"

local REQ = {}

local function reward_gen()
    return {
        itemid = 0,
		itemcnt = 0
    }
end

local function delete_oldly(ur,id)
	local tasks = ur.task.tasks
	local taskv = {}
	if not tasks then
		return false
	end
	for i = 1,#tasks do
		if tasks[i].taskid ~= id then
			taskv[#taskv + 1] = tasks[i]
		end
	end
	ur.task.tasks = taskv
	ur:db_tagdirty(ur.DB_TASK)
	--ur:send(IDUM_TASKLIST, {info = taskv})
	return true
end

local function get_next_task(taskid)
	local task_array = {}
	for k, v in pairs(tptask) do
		if v.previd == taskid then
			task_array[#task_array + 1] = k
		end
	end
	return task_array
end

REQ[IDUM_GETREWARD] = function(ur, v)
	local update = 0
    local tasks = {}
    local pkg = ur.package
    local taskid = v.taskid
    local rewardlist = {}
    local reward_list = {}
    local tp = tptask[v.taskid]
	if not tp then
		shaco.warning("the ask not exsit") 
		return 
	end
	local rewardarray = tptask[taskid].submitItems
	for j = 1,#rewardarray do
		local templist = reward_gen()
		local id = 0
		id = tonumber(rewardarray[j][1])
    	local num = 0
    	num = tonumber(rewardarray[j][2])
    	templist.itemid = id
    	templist.itemcnt = num
    	reward_list[#reward_list + 1] = templist
    	rewardlist[#rewardlist + 1] = {id,num}
	end
	if itemop.can_gain(ur, rewardlist) then
		for _, v in ipairs(rewardlist) do
			itemop.gain(ur, v[1], v[2])
		end
	end
	ur:addexp(tptask[taskid].submitExp)
	ur:gold_got(tptask[taskid].submitGold)
	ur:coin_got(tptask[taskid].submitDiamond)
	ur:sync_role_data()
	itemop.refresh(ur)
	if delete_oldly(ur,v.taskid) then
    	ur:send(IDUM_TASKREWARD, {taskid = taskid})
    end
    ur:db_tagdirty(ur.DB_ITEM)
    ur:db_tagdirty(ur.DB_TASK)
    local task_array = get_next_task(taskid)
	
	for i =1,#task_array do
		local tempv = {taskid = task_array[i]}
		REQ[IDUM_ACCEPTTASK](ur, tempv)
	end
end

REQ[IDUM_ACCEPTTASK] = function(ur, v)
    local update = 0
    local taskv = {}
    update,taskv = task.accept(ur,v.taskid)
    if not update then
    	return
    end 
	local flag = false
	local ectype_list = ur.info.ectype
	for i = 1,#ectype_list do
		if ectype_list[i].ectypeid == tptask[v.taskid].condition1 then
			flag = true 
		end
	end
	if flag == true then
		task.finish(ur,v.taskid)
		ur:send(IDUM_TASKLIST, {info = ur.task.tasks})
	else
		ur:send(IDUM_UPDATETASK, {taskid = taskv.taskid})
	end
    ur:db_tagdirty(ur.DB_TASK)
end

REQ[IDUM_TASKCHECK] = function(ur, v)
	--refresh_toclient(ur, 1,v.ectypeid,1)
	--task.pass_ectype(ur,v.ectypeid)
	--ur:db_tagdirty(ur.DB_ROLE)
end

return REQ
