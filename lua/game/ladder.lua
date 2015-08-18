local shaco = require "shaco"
local tbl = require "tbl"
local CTX = require "ctx"
local pb = require "protobuf"
local tbl = require "tbl"
local ipairs = ipairs
local tpladdershop = require "__tpladdershop"
local tpmystery_item = require "__tpmystery_item"
local tpladder_item = require "__tpladder_item"
local tppayprice = require "__tppayprice"
local tpgamedata = require "__tpgamedata"
local tpladderfixedaward = require "__tpladderfixedaward"
local tpladderexclusiveaward = require "__tpladderexclusiveaward"
local tprobotteam = require "__tprobotteam"
local config = require "config"
local card_container = require "card_container"
local club = require "club"
local scene = require "scene"
local itemop = require "itemop"
local task = require "task"
local attribute = require "attribute"
local card_attribute = require "card_attribute"
local tpladderrobot = require "__tpladderrobot"
local tpcard = require "__tpcard"
local sfmt = string.format
local floor = math.floor

local dirty_flag = {}

local ladder = {}
local ladder_record = {}
local ladder_front_five = {}
local ladder_front_hundred = {}
local rank_update = 0
local season_state = 0
local five_rank_update = 0

function ladder.init()
end

function ladder.load(all)
    ladder_record = {}
    for _, v in ipairs(all) do
        local one = pb.decode("ladder_info", v.data)
        ladder_record[#ladder_record + 1] = one
		if one.ranking <= 5 then
			ladder_front_five[#ladder_front_five + 1] = one
		end
		if one.ranking <= 100 then
			ladder_front_hundred[#ladder_front_hundred + 1] = one
			rank_update = 0
		end
    end 
end

local function ladder_shop_gen()
	return {
		refresh_time=0,
		info={},
		refresh_cnt=0,
	}
end

local function ladder_shop_item_gen()
	return {
		itemid = 0,
		itemcnt = 0,
		pos = 0,
		falg = 0,
	}
end

local function get_item_data(itemid,pos)
	local item_list = {}
	local total_weight = 0
	local tp_array = tpladder_item[itemid]
	if tp_array  then
		for i=1,#tp_array do
			if tp_array[i].mystery_item_id == itemid then
				item_list[#item_list + 1] = tp_array[i]
				total_weight = total_weight + tp_array[i].weighing
			end
		end
	end
	local random_weight = math.random(0,total_weight)
	local weight = 0
	local item_info = ladder_shop_item_gen()
	for i=1,#item_list do
		weight = weight + item_list[i].weighing 
		if weight >= random_weight then
			item_info.itemid = item_list[i].item_id
			item_info.itemcnt = item_list[i].count
			item_info.pos = pos
			item_info.falg = 0
			break
		end
	end
	return item_info
end

local function init_ladder_shop(level)
	local item_list = {}
	for k,v in pairs(tpladdershop) do
		if v.Start <= level and v.End >= level then
			for i =1,14 do
				item_list[#item_list + 1] = get_item_data(v["Item"..i],i)
			end
		end
	end
	local now = shaco.now()//1000
   -- local now_day = floor(now/86400)
    --local last_day = floor(self.info.refresh_time/86400)
	local ladder_shop = ladder_shop_gen()
	ladder_shop.refresh_time = now
	ladder_shop.info = item_list
	return ladder_shop
end

local function get_container(ur)
	local cards = card_container.get_card_container(ur.cards.__card.__cards)
    local container = {list = cards,partners = ur.cards.__partner}
	return container
end

local function _gen(ur,rank)
    return {
        	score=0,
			level=ur.base.level,
			name=ur.base.name,
			joincnt=0,
			wincnt=0,
			roleinfo=ur.info,
			ranking=rank,
			challengecnt=tpgamedata.MaxChallenge,
			refreshcnt=5,
			honor=0,
			roleid=ur.base.roleid,
			ladder_shop=init_ladder_shop(ur.base.level),
			buy_challenge_cnt=0,
			last_rank = 0,
			robot_id=0,
			opponent_info=nil,
			battle_time=0,
			container=get_container(ur),
			tpltid = ur.base.tpltid,
			battle_value = ur.battle_value,
			equip = ur.equip.__items,
			opponent_equip = {},
			opponent_level = 0,
			opponent_name = "",
			opponent_container = {},
			opponent_tpltid = 0,
			opponent_battle_value = 0,
    }
end

local function rank_info_gen(score,name,joincnt,wincnt,ranking)
	return {
		score=score,
		name=name,	
		joincnt=joincnt,
		wincnt=wincnt,
		ranking=ranking,
	}
end
local function ladder_data_gen(name)
	return {
		score=0,
		level=0,
		name=name,	
		joincnt=0,
		wincnt=0,
		ranking=0,
		challengecnt=0,
		refreshcnt=0,
		honor=0,
		last_rank = 0,
	}
end

local function _tagdirty(id)
    for _, v in ipairs(dirty_flag) do
        if v == id then
            return
        end
    end
    dirty_flag[#dirty_flag+1] = id
end

function ladder.get_role_ladder_info(roleid)
	for i =1,#ladder_record do
		if ladder_record[i].roleid == roleid then
			return ladder_record[i]
		end
	end
end

function ladder.enter_ladder(ur)
	local roleid = ur.base.roleid
	local record_info = ladder.get_role_ladder_info(roleid)
	local dirty = false
	if record_info == nil then
		record_info = _gen(ur,#ladder_record + 2)
		card_container.set_equip(ur)
		ladder_record[#ladder_record + 1] = record_info
		ladder.update_ranking(ur)
		dirty = true
	else--if ur.refesh_ladder == true then
		record_info.roleinfo = ur.info
		if ur.refesh_ladder == 2 then --card update
			ur.refesh_ladder = 0
			record_info.container = {}
			record_info.container = get_container(ur)
			card_container.set_equip(ur)
		end
		record_info.level=ur.base.level
		record_info.equip = {}
		record_info.equip = ur.equip.__items
		dirty = true
	end
	if dirty then
        _tagdirty(roleid)
    end
	local __rank = {}
	if ur.five_rank_update ~= five_rank_update then
		for i =1,#ladder_front_five do
			__rank[i] = rank_info_gen(ladder_front_five[i].score,ladder_front_five[i].name,ladder_front_five[i].joincnt,ladder_front_five[i].wincnt,ladder_front_five[i].ranking)
		end
		ur.five_rank_update = five_rank_update
	end
	local __data = ladder_data_gen(record_info.name)
	__data.score = record_info.score
	__data.level = record_info.level
	__data.joincnt = record_info.joincnt
	__data.wincnt = record_info.wincnt
	__data.ranking = record_info.ranking
	__data.challengecnt = record_info.challengecnt
	__data.refreshcnt = record_info.refreshcnt
	__data.honor = record_info.honor
	__data.last_rank = record_info.last_rank
	local now = shaco.now()//1000
	ur:send(IDUM_ACKENTERLADDER, {data = __data,rank = __rank,refresh_time = now})
	
end

function ladder.db_flush()
    if #dirty_flag == 0 then
        return
    end
    for _, id in ipairs(dirty_flag) do
        local et = ladder.get_role_ladder_info(id)
        assert(et)
        shaco.send(CTX.db, shaco.pack("S.global", {
            name="ladder_info", roleid=id, data=pb.encode("ladder_info", et) }))
    end
    dirty_flag = {}
end


function ladder.update_ranking(ur)
	local roleid = ur.base.roleid
	local record_info = ladder.get_role_ladder_info(roleid)
	local front_rank = record_info.ranking
	local function sort_score_Asc(a,b)
		if a.score == b.score then return a.name >= b.name 
		else return a.score >= b.score end
	end
	table.sort(ladder_record,sort_score_Asc)
	for i =1,#ladder_record do
		ladder_record[i].ranking = i
	end
	record_info = ladder.get_role_ladder_info(roleid)
	if record_info.ranking < front_rank and record_info.ranking <= 100 then
		rank_update = rank_update + 1
		for i =1,#ladder_record do
			if i > 100 then
				break
			end
			ladder_front_hundred[i] = ladder_record[i]
		end
	end
	if record_info.ranking < front_rank and record_info.ranking <= 5 then
		rank_update = rank_update + 1
		five_rank_update = five_rank_update + 1
		for i =1,#ladder_record do
			if i > 5 then
				break
			end
			ladder_front_five[i] = ladder_record[i]
		end
	end
end



function ladder.req_ladder_rank(ur,value_flag)
	local flag = 0
	local __rank = {}
	if ur.rank_update < rank_update then
		flag = 1
		ur.rank_update = rank_update
	end
	if flag == 1 then
		for i =1,#ladder_front_hundred do
			__rank[i] = rank_info_gen(ladder_front_hundred[i].score,ladder_front_hundred[i].name,ladder_front_hundred[i].joincnt,ladder_front_hundred[i].wincnt,ladder_front_hundred[i].ranking)
		end
	end
	ur:send(IDUM_ACKLADDERRANK, {update_flag = flag,rank = __rank})
end

function ladder.add_ladder_score(ur,score)	
	local roleid = ur.base.roleid
	local record_info = ladder.get_role_ladder_info(roleid)
	record_info.score = record_info.score + score
end

function ladder.reduce_ladder_score(ur,score)
	local roleid = ur.base.roleid
	local record_info = ladder.get_role_ladder_info(roleid)
	record_info.score = record_info.score - score
end

function ladder.req_ladder_shop(ur)
	local roleid = ur.base.roleid
	local record_info = ladder.get_role_ladder_info(roleid)
	if not record_info then
		return
	end
	local ladder_shop = record_info.ladder_shop
	local now = shaco.now()//1000
	ur:send(IDUM_ACKLADDERSHOP, {info = ladder_shop.info,refresh_cnt = ladder_shop.refresh_cnt,honor = record_info.honor,refresh_time = now})
end

function ladder.req_refresh_shop(ur)
	local roleid = ur.base.roleid
	local record_info = ladder.get_role_ladder_info(roleid)
	if not record_info then
		return
	end
	local ladder_shop = record_info.ladder_shop
	local level = ur.base.level
	local item_list = {}
	local money_type = 0
	local take = 0
	for k,v in pairs(tppayprice) do
		if v.type == 2 and v.start <= (ladder_shop.refresh_cnt + 1) and v.stop >= (ladder_shop.refresh_cnt + 1) then
			money_type = v.money_tpye
			take = v.number
			break
		end
	end
	if money_type == 0 then
		if ur:gold_take(take) == false then
			return SERR_GOLD_NOT_ENOUGH
		end
	elseif money_type == 1 then
		if record_info.honor >= take then
			record_info.honor = record_info.honor - take
		elseif record_info.honor < take then
			return SERR_HONOR_NOT_ENOUGH
		end
	end
	for k,v in pairs(tpladdershop) do
		if v.Start <= level and v.End >= level then
			for i =1,14 do
				item_list[#item_list + 1] = get_item_data(v["Item"..i],i)
			end
		end
	end
	ladder_shop.info = {}
	ladder_shop.info = item_list
	ladder_shop.refresh_cnt = ladder_shop.refresh_cnt + 1
	ur:db_tagdirty(ur.DB_ROLE)
	local now = shaco.now()//1000
	ur:send(IDUM_ACKLADDERSHOP, {info = ladder_shop.info,refresh_cnt = ladder_shop.refresh_cnt,honor = record_info.honor,refresh_time = now})
end

function ladder.changelastrank(ur,last_rank)
	local roleid = ur.base.roleid
	local record_info = ladder.get_role_ladder_info(roleid)
	if not record_info then
		return
	end
	record_info.last_rank = last_rank
end

function ladder.req_season_reward(ur)
	local roleid = ur.base.roleid
	local record_info = ladder.get_role_ladder_info(roleid)
	if not record_info then
		return
	end
	local open_server_time = config.open_server_time --开服时间
	local __time=os.date("*t",open_server_time)
	local cur_time = shaco.now()//1000 --当前时间
	local deffrent = cur_time - open_server_time
	local season = math.floor(((__time.hour - 8)*3600 + deffrent)/(3*86400))  --赛季
	
	if season <= 0 or record_info.last_rank == 0 then
		return
	end
	for k,v in pairs(tpladderfixedaward) do
		if v.Start <= record_info.last_rank and v.End >= record_info.last_rank then
			record_info.honor = record_info.honor + v.Glory
			ur:coin_got(v.Money)
			ur:gold_got(v.DMoney)
			local flag = false
			for i=1,5 do
				if v["Item"..i.."ID"] > 0 then
					itemop.gain(ur,v["Item"..i.."ID"],v["Item"..i.."Number"])
					flag = true
				end
			end
			if flag == true then
				itemop.refresh(ur)
				ur:db_tagdirty(ur.DB_ITEM)
			end
			break
		end
	end
	local tp = tpladderexclusiveaward[season]
	if not tp then
		return
	end
	for i =1,8 do
		if record_info.last_rank >= tp["Place"..i][1][1] and record_info.last_rank <= tp["Place"..i][1][2] then
			if tp["Reward"..i.."Tpye"] == REWARD_CARD then 
				local cards = ur.cards
				if cards:put(ur,tp["Reward"..i.."ID"],tp["Reward"..i.."Number"]) > 0 then
					cards.refresh(ur)
					ur:db_tagdirty(ur.DB_CARD)
				end
			elseif tp["Reward"..i.."Tpye"] == REWARD_FRAGMENT then
				club.add_fragment(ur,tp["Reward"..i.."ID"],tp["Reward"..i.."Number"])
				ur:send(IDUM_NOTICEADDFRAGMENT, {fragmentid =tp["Reward"..i.."ID"],fragment_cnt = tp["Reward"..i.."Number"]})
			end
		end
	end
	ur:db_tagdirty(ur.DB_ROLE)
	ur:sync_role_data()
	ur:send(IDUM_ACKGETLADDERREWARD, {last_season = season,last_rank = record_info.last_rank})
	record_info.last_rank = 0
end

local function is_rest_season(now)
	local open_server_time = config.open_server_time --开服时间
	local __time=os.date("*t",open_server_time)
	local deffrent = now - open_server_time
	local season = math.floor(((__time.hour - 8)*3600 + deffrent)/(3*86400)) + 1  --赛季
	local cur_season_time =((__time.hour - 8)*3600 + deffrent) - (season - 1)*3*86400
	local season_total_time = 3*86400
	if cur_season_time >= (season_total_time - 8*3600) and cur_season_time < season_total_time then
		return true
	end
	return false
end

local function get_partner_info(record_info)
	local cards = record_info.opponent_container.list
	local partners = record_info.opponent_container.partners
	local partner_info = {}
	for i = 1,#partners do
		for j=1, #cards do
			local card = cards[j]
			if card.pos == partners[i].pos then
				local partner_attribute = card_attribute.new(card.cardid,card.level,card.break_through_num)
				local par_battle_value = partner_attribute:compute_battle()
				local par_verify = partner_attribute:compute_verify()
				local __partner_info = {}
				__partner_info.par_battle_value = par_battle_value
				__partner_info.par_verify = par_verify
				__partner_info.pos = partners[i].pos
				partner_info[#partner_info + 1] = __partner_info
			end
		end
	end
	return partner_info
end

function ladder.update(now)
	local time = now//1000
    local cur_time=os.date("*t",time)
	if cur_time.hour == 24 and season_state == 0 then
		if is_rest_season(time) == true then
			season_state = 1
			for i =1,#ladder_record do
				ladder_record[i].last_rank = ranking
			end
		end
	elseif cur_time.hour == 8 and season_state == 1 then
		season_state = 0
	end
end

function ladder.req_search_opponent(ur)
	local roleid = ur.base.roleid
	local record_info = ladder.get_role_ladder_info(roleid)
	if not record_info then
		return
	end
	local now = shaco.now()//1000
	if record_info.battle_time > 0 then
		local now_day = floor(now/86400)
		local last_day = floor(record_info.battle_time/86400)
		if now_day ~= last_day then
			record_info.battle_time = 0
		else
			if record_info.robot_id > 0 then
				ur:send(IDUM_ACKSEARCHOPPONENTROBOT,{robot_id = record_info.robot_id})
			else
				ur:send(IDUM_ACKSEARCHOPPONENTROLE,{level=record_info.opponent_level,name = record_info.opponent_name,info=record_info.opponent_info,container =record_info.opponent_container,tpltid = record_info.opponent_tpltid,battle_value = record_info.opponent_battle_value,equip = record_info.opponent_equip})
			end
			return
		end
	end
	record_info.battle_time = now
	local score = record_info.score
	local max_score = score + 20
	local min_score = score - 20
	if min_score < 0 then
		min_score = 0
	end
	if score <= tpgamedata.LadderPVP then
		local robot_list = {}
		for k,v in pairs(tprobotteam) do
			if  v.Integral >= min_score and v.Integral <= max_score then
				robot_list[#robot_list + 1] = v
			end
		end
		local random_indx = math.random(1,(#robot_list))
		local select_target = robot_list[random_indx]
		record_info.robot_id=select_target.id
		ur:send(IDUM_ACKSEARCHOPPONENTROBOT,{robot_id = select_target.id})
	else
		local target_list = {}
		for i =1,#ladder_record do
			if ladder_record[i].roleid ~= roleid  and ladder_record[i].score >= min_score and ladder_record[i].score <= max_score then
				
				target_list[#target_list + 1] = ladder_record[i]
			end
		end
		local flag = false
		if #target_list > 0 then
			local random_indx = math.random(1,#target_list)
			local select_target = target_list[random_indx]
			--tbl.print(select_target, "=====!!!!!!!!!!!!!!!========init select_target", shaco.trace)
			if select_target then
				flag = true
				record_info.opponent_info = select_target.roleinfo
				record_info.opponent_equip = {}
				record_info.opponent_equip = select_target.equip
				record_info.opponent_level = select_target.level
				record_info.opponent_name = select_target.name
				record_info.opponent_container = select_target.container
				record_info.opponent_tpltid = select_target.tpltid
				record_info.opponent_battle_value = select_target.battle_value
				record_info.opponent_info = select_target.roleinfo
				ur:send(IDUM_ACKSEARCHOPPONENTROLE,{level=select_target.level,name = select_target.name,info=select_target.roleinfo,container =select_target.container,tpltid = select_target.tpltid,battle_value = select_target.battle_value,equip = select_target.equip})
				return
			else
				flag = false
			end
		else
			local temp_list = {}
			local __flag = false
			for i =1,10000 do
				if __flag == true then
					break
				end
				for i =1,#ladder_record do
					local __min_score = min_score - 20*i
					if __min_score <= 0 then
						__min_score = 0
					end
					local __max_score = max_score - 20*i
					if __max_score <= 0 then
						__max_score = 0
					end
					if ladder_record[i].roleid ~= roleid  and ladder_record[i].score >= __min_score and ladder_record[i].score <= __max_score then
						temp_list[#temp_list + 1] = ladder_record[i]
						__flag = true
					end
				end
			end
			if #temp_list > 0 then
				local random_indx = math.random(1,#temp_list)
				local select_target = temp_list[random_indx]
				if select_target then
					flag = true
					record_info.opponent_info = select_target.roleinfo
					record_info.opponent_equip = {}
					record_info.opponent_equip = select_target.equip
					record_info.opponent_level = select_target.level
					record_info.opponent_name = select_target.name
					record_info.opponent_container = select_target.container
					record_info.opponent_tpltid = select_target.tpltid
					record_info.opponent_battle_value = select_target.battle_value
					ur:send(IDUM_ACKSEARCHOPPONENTROLE,{level=select_target.level,name = select_target.name,info=select_target.roleinfo,container =select_target.container,tpltid = select_target.tpltid,battle_value = select_target.battle_value,equip = select_target.equip})
					return
				else
					flag = false
				end
			end
		end
		if flag == false then
			local select_target = {}
			for k,v in pairs(tprobotteam) do
				if  v.Integral == tpgamedata.LadderPVP then
					select_target = v
				end
			end
			record_info.robot_id = select_target.id
			ur:send(IDUM_ACKSEARCHOPPONENTROBOT,{robot_id = select_target.id})
		end
	end
end


local function card_battle_value(monsterid)
	local ladder_monster =  tpladderrobot[monsterid]
	local tp = tpcard[ladder_monster.card]
	local battle_value = 0
	battle_value = tp.atk + tp.magic + tp.def + tp.magicDef + tp.hP + tp.atkCrit + tp.magicCrit + tp.atkResistance + tp.magicResistance + tp.blockRate + tp.dodgeRate  + tp.hits
				   + tp.level*(tp.hPRate + tp.atkRate + tp.defRate + tp.magicRate + tp.magicDefRate + tp.atkResistanceRate + tp.magicResistanceRate + tp.dodgeRateRate + tp.atkCritRate + tp.magicCritRate + tp.blockRateRate + tp.hitsRate)
	local verify_value = tp.hP/ math.max(tp.atk + tp.level*tp.atkRate + tp.magic + tp.level*tp.magicRate - (tp.def + tp.level*tp.defRate + tp.magicDef + tp.level*tp.magicDefRate),1)
	return battle_value,verify_value
end

local function get_min_value(value1,value2,value3)
	if value1 -  value2 < 0 and value1 - value3 < 0 then
		return true
	end
	return false
end

local function get_robot_min_verify(robot_id)
	local oppent_value = 0
	local tp = tprobotteam[robot_id]
	if not tp then
		return oppent_value
	end
	local frist_battle,frist_oppent = card_battle_value(tp.monster1)
	local second_battle,second_oppent = card_battle_value(tp.monster2)
	local third_battle,third_oppent = card_battle_value(tp.monster3)
	if get_min_value(frist_battle,second_battle,third_battle) then
		oppent_value = frist_oppent
	elseif get_min_value(second_battle,frist_battle,third_battle) then
		oppent_value = second_oppent
	elseif get_min_value(third_battle,second_battle,frist_battle) then
		oppent_value = third_oppent
	end
	return oppent_value
end

local function get_opponent_min_attribute(record_info)
	local verify_value = 0
	if record_info.robot_id > 0 then
		verify_value = get_robot_min_verify(record_info.robot_id)
		return verify_value
	end
	local attributes = attribute.new(0,0,record_info.opponent_info.attribute,true)
	local battle_value = attributes:get_battle_value()
	verify_value = attributes:compute_verify()
	local cards = record_info.opponent_container.list
	local partners = record_info.opponent_container.partners
	local partner_info = get_partner_info(record_info)
	local min_indx = 0
	if #partner_info > 1 then
		if partner_info[1].par_battle_value < partner_info[2].par_battle_value then
			min_indx = 1
		else
			min_indx = 2
		end
	else
		min_indx = 1
	end
	if partner_info[min_indx].par_battle_value > battle_value then
		return verify_value
	else
		return partner_info[min_indx].par_verify
	end
end

local function verify_battle(ur,record_info)
	local oppent_value = get_opponent_min_attribute(record_info)
	local verify_value = ur:get_max_atrribute()
	if verify_value*1.5/oppent_value >= 1 then
		ur.battle_verify = true
	else
		ur.battle_verify = false
	end
end

function ladder.req_enter_ladder_scene(ur)
	local roleid = ur.base.roleid
	local record_info = ladder.get_role_ladder_info(roleid)
	if not record_info then
		return
	end
	if record_info.challengecnt <  1 then
		return
	end
	local __sceneid = 3001
	local ok = scene.enter(ur, __sceneid)
    if ok then	
		verify_battle(ur,record_info)
		record_info.joincnt = record_info.joincnt + 1
		record_info.challengecnt = record_info.challengecnt - 1
		ur:send(IDUM_ACKENTERLADDERSCENE, {sceneid = __sceneid,joincnt = record_info.joincnt,challengecnt = record_info.challengecnt})
		task.set_task_progress(ur,19,record_info.joincnt,0)
		task.refresh_toclient(ur, 19)
	end
end

function ladder.add_honor(ur,id,add_count)
	local roleid = ur.base.roleid
	local record_info = ladder.get_role_ladder_info(roleid)
	if not record_info then
		return
	end
end

function ladder.add_ladder_honor(ur,honor)
	local roleid = ur.base.roleid
	local record_info = ladder.get_role_ladder_info(roleid)
	if not record_info then
		return
	end
	record_info.honor =  record_info.honor + honor
end

local function system_refresh_shop(ur)
	local roleid = ur.base.roleid
	local record_info = ladder.get_role_ladder_info(roleid)
	if not record_info then
		return
	end
	local ladder_shop = record_info.ladder_shop
	local level = ur.base.level
	local item_list = {}
	for k,v in pairs(tpladdershop) do
		if v.Start <= level and v.End >= level then
			for i =1,14 do
				item_list[#item_list + 1] = get_item_data(v["Item"..i],i)
			end
		end
	end
	ladder_shop.info = {}
	ladder_shop.info = item_list
	ladder_shop.refresh_cnt = 0
	local now = shaco.now()//1000
	ur:send(IDUM_ACKLADDERSHOP, {info = ladder_shop.info,refresh_cnt = ladder_shop.refresh_cnt,honor = record_info.honor,refresh_time = now})
end

function ladder.onchangeday(ur)
	local roleid = ur.base.roleid
	local record_info = ladder.get_role_ladder_info(roleid)
	if not record_info then
		return
	end
	record_info.challengecnt = tpgamedata.MaxChallenge
	record_info.buy_challenge_cnt = 0
	system_refresh_shop(ur)
end

return ladder
