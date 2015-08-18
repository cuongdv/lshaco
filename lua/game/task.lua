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
local task_fast = require "task_fast"
local tpgamedata = require "__tpgamedata"
local task = {}
--math.randomseed(os.time())

local function task_base_gen()
    return {
        taskid = 0,
		finish = 0,
		taskprogress = 0,
		taskprogress2 = 0,
    }
end

local function pass_ectype_gen()
	return {
		ectypeid = 0,
		star = 0,
	}
end

local function check_state(taskv, task_type, parameter1, parameter2)
    local t
	local taskid = 0;
	for k, v in ipairs(taskv) do
        t = tptask[v.taskid]
		if t and t.method == task_type and t.condition1 == v.taskprogress and t.condition2 == v.taskprogress2 then
			taskid = v.taskid
			break
		end
	end
	return taskid
end


function task.new(type, taskv)
    local tasks = {}
    local idx = 1
    for k, v in ipairs(taskv) do
        if v.taskid == 0 then
            shaco.warning("tasklist taskid zero")
        else
        	local task = tasks[idx] 
            if task then
                shaco.warning("task repeat")
           	else
                tasks[idx] = v
            end
            idx = idx + 1 
        end
    end
    local task = {
        tasks = tasks,
    }
    return task
end

local function check_exsit(tasks,id)
	for i = 1,#tasks do
		if tasks[i].taskid == id then
			shaco.warning("the ask already exsit")
			return 0
		end
	end
	return 1
end

function task.accept(ur,id)
	local task = task_base_gen()
	local tasks = ur.task.tasks
	local tp = tptask[id]
	if not tp then
		shaco.warning("the ask not exsit") 
		return 0,task
	end
	if check_exsit(tasks,id)  == 1 then --ur.base.level < tp.level and 
		local flag = false
		for i=1, #tasks do
			if tasks[i].taskid == 0 then
				tasks[i].taskid = id
				tasks[i].finish = 0
				tasks[i].taskprogress = 0
				flag = true
				break
			end
		end
		if flag == false then
			task.taskid = id
			task.finish = 0
			task.taskprogress = 0
			tasks[#tasks +1] = task
		end
	else
		return 0,task
	end	
	ur.task.tasks = tasks	
	return 1,task
end

function task.finish(ur,id)
	local tasks = ur.task.tasks
	for i = 1,#tasks do
		if tasks[i].taskid == id then
			ur.task.tasks[i].finish = 1
			return true
		end
	end
	return false
end

local function check_refresh_time(ur)
	local updatetime = 3
	local time = os.time()
	local curtime=os.date("*t",time)
	local refresh_time = shaco.now()//1000--ur.info.refresh_time
	local lasttime=os.date("*t",refresh_time)
	if curtime.year > lasttime.year then
		return true
	else	
		if curtime.month > lasttime.month then
			return true
		else
			if curtime.day > lasttime.day and curtime.hour >= updatetime then
				return true
			end
		end
	end
	
	return false
end

local function clear_daily(ur)
	local newtasks = {}
	local tasks = ur.task.tasks
	for k, v in ipairs(tasks) do
		local tp = tptask[v.taskid]
		if tp and tp.type == DAILY_TASK then
			v.taskid = 0
			v.finish = 0
			v.taskprogress = 0
		end
		--if v.tasktype ~= 2 then
		--	newtasks[#newtasks + 1] = v
		--end
	end
	--ur.task.tasks = newtasks
end

function task.daily_update(ur)
	if ur.base.level < tpgamedata.dayTaskLevel then
		return false
	end
	local flag,daily_list = task_fast.update_daliy(ur)
	if flag == false then
		return false
	end
	clear_daily(ur)
	for i=1,#daily_list do
		task.accept(ur,daily_list[i])
 	end
 	return true
end

function task.refresh_toclient(ur, task_type,parameter1,parameter2)
	local tasks = ur.task.tasks
	if not tasks then
		return
	end 
	local taskid = check_state(tasks, task_type)
	if taskid == 0 then
		return
	end
	task.finish(ur,taskid)
	ur:db_tagdirty(ur.DB_TASK)
	ur:send(IDUM_TASKLIST, {info = tasks})
end

function task.first_accept(ur)
	for k, v in pairs(tptask) do
		if v.previd == 0 and v.type == 1 or v.type == 2 and v.level <= ur.base.level then
			local update = 0
			local taskv = {}
			local tasks = {}
			task.accept(ur,k)
			--[[update,taskv = task.accept(ur,k)
			if not update then
				return
			end 
			ur:send(IDUM_UPDATETASK, {taskid = taskv.taskid})
			ur:db_tagdirty(ur.DB_TASK)]]
		end
	end
end

function task.change_task_progress(ur,method,flag)
	local tasks = ur.task.tasks or {}
	for k, v in ipairs(tasks) do
		local tp = tptask[v.taskid]
		if tp and tp.method == method then
			if flag == 1 then
				v.taskprogress = v.taskprogress + 1
			else
				v.taskprogress = 0
			end
		end
	end
end

function task.set_task_progress(ur,method,progress,progress2)
	local tasks = ur.task.tasks
	for k, v in ipairs(tasks) do
		local tp = tptask[v.taskid]
		if tp and tp.method == method then
			v.taskprogress = progress
			break
		end
	end
end

function task.update_daily_task(ur)
	if ur.base.level < tpgamedata.dayTaskLevel then
		return true
	end
	local flag,daily_list = task_fast.update_daliy(ur)
	if flag == false then
		return false
	end
	clear_daily(ur)
	for i=1,#daily_list do
		task.accept(ur,daily_list[i])
 	end
	ur:db_tagdirty(ur.DB_ROLE)
    ur:db_tagdirty(ur.DB_TASK)
	ur:send(IDUM_TASKLIST, {info = ur.task.tasks})
	return true
end

function task.accept_daily_task(ur)
	local flag = false
	local tasks = ur.task.tasks
	for k, v in ipairs(tasks) do
		local tp = tptask[v.taskid]
		if tp and tp.type == DAILY_TASK then
			flag = true
			break
		end
	end
	if flag then
		return
	end
	task.update_daily_task(ur)
end

return task
