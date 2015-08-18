local shaco = require "shaco"
local scene = require "scene"
local itemdrop = require "itemdrop"
local tbl = require "tbl"
local sfmt = string.format
local ladder = require "ladder"
local tpladder_item = require "__tpladder_item"
local tpgamedata = require "__tpgamedata"
local tppayprice = require "__tppayprice"
local config = require "config"
local task = require "task"
local itemop = require "itemop"
local REQ = {}

REQ[IDUM_REQENTERLADDER] = function(ur, v)
	ladder.enter_ladder(ur)
end

REQ[IDUM_REQLADDERRANK] = function(ur, v)
	ladder.req_ladder_rank(ur,v.flag)
	
end

REQ[IDUM_REQLADDERSHOP] = function(ur, v)
	ladder.req_ladder_shop(ur)
end

REQ[IDUM_REQREFRESHLADDERSHOP] = function(ur, v)
	ladder.req_refresh_shop(ur)
end

REQ[IDUM_REQBUYITEMFROMLADDERSHOP] = function(ur, v)
	local roleid = ur.base.roleid
	local record_info = ladder.get_role_ladder_info(roleid)
	if not record_info then
		return
	end
	local item_list = record_info.ladder_shop.info
	local flag = false
	for i =1,#item_list do
		if v.itemid == item_list[i].itemid and item_list[i].itemcnt == v.itemcnt and item_list[i].falg == 0 then
			flag = true
			break
		end
	end
	
	if flag == false then
		return SERR_BUY_OVER
	end
	local take = 0
	for k,u in pairs(tpladder_item) do
		for i =1,#u do
			if u[i].item_id == v.itemid and u[i].count == v.itemcnt then
				take = u[i].money_count
				break
			end
		end
	end
	if record_info.honor < take then
		return SERR_HONOR_NOT_ENOUGH
	end

	local left_cnt = 0
	for i =1,#item_list do
		if v.itemid == item_list[i].itemid and item_list[i].itemcnt == v.itemcnt and v.pos == item_list[i].pos then
			left_cnt = item_list[i].itemcnt
			record_info.honor = record_info.honor - take
			itemop.gain(ur,v.itemid,v.itemcnt)
			item_list[i].falg = 1
			itemop.refresh(ur)
			ur:db_tagdirty(ur.DB_ITEM)
			break
		end
	end
	ur:send(IDUM_ACKBUYITEMFROMLADDERSHOP, {itemid = v.itemid,cnt = left_cnt,pos = v.pos,honor = record_info.honor})
end

REQ[IDUM_REQBUYCHALLENGECNT] = function(ur, v)
	local roleid = ur.base.roleid
	local record_info = ladder.get_role_ladder_info(roleid)
	if not record_info then
		return
	end
	local buy_count = record_info.buy_challenge_cnt
	if record_info.challengecnt >= tpgamedata.MaxChallenge then
		return SERR_MAX_LADDER_CHALLENGE_CNT
	end
	local take = 0
	for k,u in pairs(tppayprice) do
		if u.type == 4 and u.start <= (buy_count + 1) and u.stop >= (buy_count + 1) then
			take = u.number
			break
		end
	end
	if ur:gold_take(take) == false then
		return SERR_GOLD_NOT_ENOUGH
	end
	record_info.buy_challenge_cnt = record_info.buy_challenge_cnt + 1
	record_info.challengecnt = record_info.challengecnt + 1
	task.set_task_progress(ur,46,1,0)
	task.refresh_toclient(ur, 46)
	ur:send(IDUM_ACKBUYCHALLENGECNT,{challenge_cnt = record_info.challengecnt,buy_count = record_info.buy_challenge_cnt})
end

REQ[IDUM_REQGETLADDERREWARD] = function(ur, v)
	ladder.req_season_reward(ur)
end

REQ[IDUM_REQSEARCHOPPONENT] = function(ur, v)
	local open_server_time = config.open_server_time --开服时间
	local __time=os.date("*t",open_server_time)
	local cur_time = shaco.now()//1000 --当前时间
	local deffrent = cur_time - open_server_time
	local season = ((__time.hour - 8)*3600 + deffrent)//(3*86400) + 1  --赛季
	local cur_season_time =((__time.hour - 8)*3600 + deffrent) - (season - 1)*3*86400
	local season_total_time = 3*86400
	if cur_season_time > (season_total_time - 8*3600) then
		return SERR_SEASON_REST
	end
	ladder.req_search_opponent(ur)
end

REQ[IDUM_REQENTERLADDERSCENE] = function(ur, v)
	local open_server_time = config.open_server_time --开服时间
	local cur_time = shaco.now()//1000 --当前时间
	local __time=os.date("*t",open_server_time)
	local deffrent = cur_time - open_server_time
	local season = ((__time.hour - 8)*3600 + deffrent)//(3*86400) + 1  --赛季
	local cur_season_time =((__time.hour - 8)*3600 + deffrent) - (season - 1)*3*86400
	local season_total_time = 3*86400
	if cur_season_time > (season_total_time - 8*3600) then
		return SERR_SEASON_REST
	end
	task.set_task_progress(ur,32,0,0)
	task.refresh_toclient(ur, 32)
	ladder.req_enter_ladder_scene(ur)
end

REQ[IDUM_NOTICEBATTLEOVER] = function(ur, v)
	local roleid = ur.base.roleid
	local record_info = ladder.get_role_ladder_info(roleid)
	if not record_info then
		return
	end
	if v.battle_result == 1 then --win
		record_info.score = record_info.score + tpgamedata.WinIntegral
		record_info.honor = record_info.honor + tpgamedata.WinHonor
		task.change_task_progress(ur,35,1)
		task.refresh_toclient(ur, 35)
		task.set_task_progress(ur,20,1,0)
		task.refresh_toclient(ur, 20)
		record_info.wincnt = record_info.wincnt + 1
	elseif v.battle_result == 2 then
		record_info.score = record_info.score + tpgamedata.LoseIntegral
		record_info.honor = record_info.honor + tpgamedata.LoseHonor
		task.change_task_progress(ur,35,0)
	end
	record_info.battle_time=0
	record_info.robot_id = 0
	record_info.opponent_info = nil
	task.refresh_toclient(ur, 34,record_info.honor,0)
	ladder.update_ranking(ur)
	if not ur.battle_verify then
		if v.battle_result == 1 then
			ur:x_log_role_cheat(0,0,record_info.robot_id,record_info.opponent_battle_value)
		end
	end
end

return REQ
