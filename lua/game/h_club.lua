--local shaco = require "shaco"
local shaco = require "shaco"
local pb = require "protobuf"
local tbl = require "tbl"
local sfmt = string.format
local ipairs = ipairs
local pairs = pairs
local tonumber = tonumber
local tostring = tostring
local itemop = require "itemop"
local club = require "club"
local scene = require "scene"
local tpclub = require "__tpclub"
local tpclub_treasure = require "__tpclub_treasure"
local tpsplinter_shop = require "__tpsplinter_shop"
local tppayprice = require "__tppayprice"
local card_container = require "card_container"
local tpclub_card = require "__tpclub_card"
local task = require "task"
local REQ = {}

local function dazzle_fragment_gen()
	return {
		fragmentid = 0,
	}
end

REQ[IDUM_REQ_REFRESH_CLUB] = function(ur, v)
	local cnt = ur.club.club_refresh_cnt + 1
	local take = 0
	local money_tpye = 0
	for k, u in pairs(tppayprice) do
		if u.type == 3 and cnt >= u.start and cnt <= u.stop then
			take = u.number
			money_tpye = u.money_tpye
			break
		end
	end
	if money_tpye == 0 then
		if ur:coin_take(take) == false then
			return SERR_COIN_NOT_ENOUGH
		end
	elseif money_tpye == 1 then
		if ur:gold_take(take) == false then
			return SERR_GOLD_NOT_ENOUGH
		end
	end
	local club = club.refresh_club(ur,cnt)
	ur.club = club
	ur:sync_role_data()
	ur:db_tagdirty(ur.DB_ROLE)
	ur:db_tagdirty(ur.DB_CLUB)
	ur:send(IDUM_ACKRESHRESHCLUB, {info = club})
end

local function card_battle_value(cardid)
	local tp = tpclub_card[cardid]
	local battle_value = 0
	battle_value = tp.atk + tp.magic + tp.def + tp.magicDef + tp.hP + tp.atkCrit + tp.magicCrit + tp.atkResistance + tp.magicResistance + tp.blockRate + tp.dodgeRate  + tp.hits
				   + tp.level*(tp.hPRate + tp.atkRate + tp.defRate + tp.magicRate + tp.magicDefRate + tp.atkResistanceRate + tp.magicResistanceRate + tp.dodgeRateRate + tp.atkCritRate + tp.magicCritRate + tp.blockRateRate + tp.hitsRate)
	local verify_value = tp.hP/ math.max(tp.atk + tp.level*tp.atkRate + tp.magic + tp.level*tp.magicRate - (tp.def + tp.level*tp.defRate + tp.magicDef + tp.level*tp.magicDefRate),1)
	return battle_value,verify_value
end

local function get_max_value(value1,value2,value3)
	if value1 -  value2 < 0 and value1 - value3 < 0 then
		return true
	end
	return false
end

local function verify_battle(ur,clubid)
	local tp = tpclub[clubid]
	if not tp then
		return 
	end
	local oppent_value = 0
	local frist_battle,frist_oppent = card_battle_value(tp.frist_card)
	local second_battle,second_oppent = card_battle_value(tp.second_card)
	local third_battle,third_oppent = card_battle_value(tp.third_card)
	if get_max_value(frist_battle,second_battle,third_battle) then
		oppent_value = frist_oppent
	elseif get_max_value(second_battle,frist_battle,third_battle) then
		oppent_value = second_oppent
	elseif get_max_value(third_battle,second_battle,frist_battle) then
		oppent_value = third_oppent
	end
	local verify_value = ur:get_max_atrribute()
	if verify_value*1.5/oppent_value >= 1 then
		ur.battle_verify = true
	else
		ur.battle_verify = false
	end
end

REQ[IDUM_REQENTERCLUBSCENE] = function(ur, v)
	local club_info = ur.club
	local crop_state = 0
	for i=1,#club_info.crops do
		if club_info.crops[i].corpsid == v.clubid then
			crop_state = club_info.crops[i].corps_state
			break
		end
	end
	if crop_state == OVER_CHALLENGE then
		return SERR_CLUB_ALREADY_CHALLENGE_OVER
	end
	local tp = tpclub[v.clubid]
	if not tp then
		return SERR_ERROR_LABEL
	end
	
	local ok = scene.enter(ur, tp.customspass)
    if ok then	
		for i=1,#club_info.crops do
			if club_info.crops[i].corpsid == v.clubid then
				if crop_state == NOT_CHALLENGE then
					crop_state = crop_state + 1
					club_info.crops[i].corps_state = crop_state
				end
				break
			end
		end
		verify_battle(ur,v.clubid)
		ur.info.map_entertime = shaco.now()//1000;
		task.set_task_progress(ur,40,0,0)
		task.refresh_toclient(ur, 40)
		ur:send(IDUM_ACKENTERCLUBSCENE, {clubid = v.clubid,state = crop_state})
		ur:db_tagdirty(ur.DB_CLUB)
	end
end

REQ[IDUM_REQEXCHANGECARD] = function(ur, v)
	local tp = tpsplinter_shop[v.cardid]
	if not tp then
		return 
	end
	local club_info = ur.club
	local flag = false
	for i =1,#club_info.card_framgent do
		if club_info.card_framgent[i].card_framgent_id == tp.chip_quantity[1][1] then
			if card_container.enough(ur,v.card_count) == false then
				return SERR_CARD_BAG_SIZE_NOT_ENOUGH
			end
			if club_info.card_framgent[i].count >= tp.chip_quantity[1][2] * v.card_count then
				club_info.card_framgent[i].count = club_info.card_framgent[i].count - tp.chip_quantity[1][2] * v.card_count 
				flag = true
				break
			elseif v.buy_type == USE_OMNIPOTENT_FRAGMENT then
				if tp.quality == CARD_VIOLET then
					if club_info.card_framgent[i].count + club_info.violet_framgent >= tp.chip_quantity[1][2] * v.card_count then
						club_info.violet_framgent = club_info.card_framgent[i].count + club_info.violet_framgent - tp.chip_quantity[1][2] * v.card_count 
						club_info.card_framgent[i].count = 0
						club_info.card_framgent[i].card_framgent_id = 0
						flag = true
						break
					else
						break
					end
				elseif tp.quality == CARD_ORANGE then
					if club_info.card_framgent[i].count + club_info.orange_framgent >= tp.chip_quantity[1][2] * v.card_count then
						club_info.orange_framgent = club_info.card_framgent[i].count + club_info.orange_framgent - tp.chip_quantity[1][2] * v.card_count 
						club_info.card_framgent[i].count = 0
						club_info.card_framgent[i].card_framgent_id = 0
						flag = true
						break
					else
						break
					end
				end
			end
		end
	end
	if flag == false then
		return SERR_CARD_FRAGMENT_NOT_ENOUGH
	end
	if ur.cards:put(ur,v.cardid,v.card_count) > 0 then
		card_container.refresh(ur)
		ur:db_tagdirty(ur.DB_CARD)
	end
	ur:db_tagdirty(ur.DB_CLUB)
	ur:send(IDUM_ACKEXCHANGECARD, {info = club_info})
end

REQ[IDUM_NOTICEENTERTEAMBATTLE] = function(ur, v)
	ur.info.map_entertime = shaco.now()//1000;
end

local function get_item(ur,lucky_draw,item_list)
	local total_weight = 0
	local club_treasure_list = {}
	local tp = tpclub_treasure[lucky_draw]
	for i = 1,#tp do
		local function check_exsit(item_list,item_id,count,item_type)
			for j =1,#item_list do
				if item_list[j].itemid == item_id and item_list[j].itemcnt == count and item_list[j].item_type == item_type then
					return false
				end
			end
			return true
		end
		if check_exsit(item_list,tp[i].item_id,tp[i].count,tp[i].type) then
			total_weight = total_weight + tp[i].weighing 
			club_treasure_list[#club_treasure_list + 1] = tp[i]
		end
	end
	local random_value = math.random(0,total_weight)
	local weight = 0
	local itemid = 0
	local itemcnt = 0
	local item_type = 0
	for i = 1,#club_treasure_list do
		weight = weight + club_treasure_list[i].weighing
		if weight >= random_value then
			itemid = club_treasure_list[i].item_id
			itemcnt = club_treasure_list[i].count
			item_type = club_treasure_list[i].type
			break
		end
	end
	if item_type == 1 then
		itemop.gain(ur,itemid,itemcnt)
		itemop.refresh(ur)
		ur:db_tagdirty(ur.DB_ITEM)
	elseif item_type == 2 then
		local cards = ur.cards
		if cards:put(ur,itemid,itemcnt) > 0 then
			cards.refresh(ur)
			ur:db_tagdirty(ur.DB_CARD)
		end
	elseif item_type == 3 then
		club.add_fragment(ur,itemid,itemcnt)	
		ur:send(IDUM_NOTICEADDFRAGMENT, {fragmentid =itemid,fragment_cnt = itemcnt})
	end
	
	return itemid,itemcnt,item_type
end

local function random_count(countv)
	local total_weight = 0
	local count_list = {}
	for i = 1,#countv do
		if #countv[i] > 0 then
			total_weight = total_weight + countv[i][2] 
			count_list[#count_list + 1] = countv[i]
		end
	end
	local random_value = math.random(0,total_weight)
	local weight = 0
	local itemcnt = 0
	for i = 1,#count_list do
		weight = weight + count_list[i][2]
		if weight >= random_value then
			itemcnt = count_list[i][1]
			break
		end
	end
	return itemcnt
end

local function get_club_reward(ur,clubid)
	local club_info = ur.club
	local tp = tpclub[clubid]
	if not tp then
		return 
	end
	local score = 0
	local lucky_draw = 0
	local random_cnt = 0
	if  club_info.score >= 1 and  club_info.score <=2 then
		lucky_draw = tp.lucky_draw1
		random_cnt = random_count(tp.item_count1)
	elseif  club_info.score >= 3 and  club_info.score <=4 then
		lucky_draw = tp.lucky_draw2
		random_cnt = random_count(tp.item_count2)
	elseif  club_info.score >= 5 and  club_info.score <=6 then
		lucky_draw = tp.lucky_draw3
		random_cnt = random_count(tp.item_count3)
	end
	club_info.score = 0
	local function item_base_gen()
		return {
			itemid=0,
			itemcnt=0,
			item_type = 0,
		}
	end
	local item_list = {}
	for j = 1,random_cnt do
		local item_base = item_base_gen()
		item_base.itemid,item_base.itemcnt,item_base.item_type= get_item(ur,lucky_draw,item_list)
		item_list[#item_list + 1] = item_base
	end
	itemop.refresh(ur)
	ur:db_tagdirty(ur.DB_ITEM)
	ur:db_tagdirty(ur.DB_CLUB)
	ur:send(IDUM_EXTRACTREWARD, {item_list = item_list})
end



REQ[IDUM_CHALLENGEOVER] = function(ur, v)
	local club_info = ur.club
	local score = 0
	local tp = tpclub[v.clubid]
	if not tp then
		return SERR_ERROR_LABEL
	end
	local battle_over = false
	for i =1,#club_info.crops do
		if club_info.crops[i].corpsid == v.clubid then
			if club_info.crops[i].corps_state == PERSONAL_CHALLENGE then
				club_info.crops[i].corps_state = TEAM_CHALLENGE
				local pass_time = shaco.now()-ur.info.map_entertime*1000
				if v.die_flag == 0 then
					if pass_time - v.battle_time < tp.personal_1star  then
					
					end
					if tp.personal_1star < v.battle_time then
						score =0
					elseif tp.personal_1star >= v.battle_time and tp.personal_2star < v.battle_time then
						score =1
					elseif tp.personal_2star >= v.battle_time and tp.personal_3star < v.battle_time then
						score =2
					elseif tp.personal_3star >= v.battle_time then
						score =3
					end
				else
					score =0
				end
			elseif club_info.crops[i].corps_state == TEAM_CHALLENGE then
				club_info.crops[i].corps_state = OVER_CHALLENGE
				if v.die_flag == 0 then
					local pass_time = shaco.now() - ur.info.map_entertime* 1000
					if tp.personal_1star < v.battle_time then
						score =0
					elseif tp.personal_1star >= v.battle_time and tp.personal_2star < v.battle_time then
						score =1
					elseif tp.personal_2star >= pass_time and tp.personal_3star < v.battle_time then
						score =2
					elseif tp.personal_3star >= v.battle_time then
						score =3
					end
				else
					score =0
				end
				battle_over = true
			end
			club_info.score = club_info.score + score
			break
		end
	end
	ur:send(IDUM_CHALLENGERESULT, {info = club_info})	
	if battle_over == true then
		get_club_reward(ur,v.clubid)
		task.set_task_progress(ur,41,tp.club_hardness,0)
		task.refresh_toclient(ur, 41)
		if not ur.battle_verify then
			if club_info.score >= 5 then
				ur:x_log_role_cheat(0,v.clubid,0,0)
			end
		end
	end
	ur:db_tagdirty(ur.DB_CLUB)
end

REQ[IDUM_REQCLUBINFO] = function(ur, v)
	ur:send(IDUM_NOTICECLUBINFO, {info = ur.club})
end

return REQ

