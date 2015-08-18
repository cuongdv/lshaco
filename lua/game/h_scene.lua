local shaco = require "shaco"
local scene = require "scene"
local tpscene = require "__tpscene"
local itemdrop = require "itemdrop"
local tpgamedata = require "__tpgamedata"
local tpmonster = require "__tpmonster"
local tbl = require "tbl"
local sfmt = string.format
local floor = math.floor
local REQ = {}

local function is_copy(tp)
    return tp.type == SCENE_COPY
end

local function item_list_gen()
	return {
		itemid = 0,
		cnt = 0,
		drop_type = 0,
	}	
end

local function random_count(countv)
	local total_weight = 0
	local count_list = {}
	for i = 1,#countv do
		if #countv[i] > 0 and countv[i][2] then
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

local function  get_drop_data(drop_count,drop_data,__type,item_list)
	for i =1, drop_count do
		local function get_drop_list(drop_list,items)
			local temp_list = {}
			for j=1,#drop_list do
				local flag = false
				for k =1,#items do
					if drop_list[j][1] == items[k].itemid and __type == items[k].drop_type then
						flag = true
						break
					end
				end
				if flag == false then
					temp_list[#temp_list + 1] = drop_list[j]
				end
			end
			return temp_list
		end
		local drop_list = get_drop_list(drop_data,item_list)
		local taotal_weight = 0
		for j =1,#drop_list do
			taotal_weight = drop_list[j][3] + taotal_weight
		end
		local weight = 0
		local random_weight =  math.random(0,taotal_weight)
		for j =1,#drop_list do
			weight = drop_list[j][3] + weight
			if weight >= random_weight then
				item_list[#item_list+1] = item_list_gen()
				item_list[#item_list].itemid = drop_list[j][1]
				item_list[#item_list].cnt = drop_list[j][2]
				item_list[#item_list].drop_type = __type
				break
			end
		end
	end
	return item_list
end

local function verify_battle(ur,cheat,ectypeid)
	local tp = tpmonster[cheat]
	if not tp then
		return
	end
	local oppent_value = tp.hp/ math.max(tp.phyAtk + tp.magAtk - tp.phyDef - tp.magDef,1)
	shaco.trace(sfmt("oppent_value == %d ..~~~~~~~~~~~~~~~~~~~.", oppent_value))
	local verify_value = ur:get_max_atrribute()
	if verify_value*1.5/oppent_value >= 1 then
		ur.battle_verify = true
	else
		ur.battle_verify = false
	end
end

REQ[IDUM_SCENEENTER] = function(ur, v)
    local mapid = v.mapid
	local tp = tpscene[mapid]
	if not tp then
		return
	end
	if not ur.info.physical or ur.info.physical < tp.physicalNeed then
		return SERR_PYSICAL_NOT_ENOUGH
	end
	local drop_count = random_count(tp.monster_drop_count)
	local boss_count1 = random_count(tp.boss_drop_count1)
	local boss_count2 = random_count(tp.boss_drop_count2)
    local ok = scene.enter(ur, mapid)
    if ok then
        ur.info.map_entertime = shaco.now()//1000;
		local randomcnt = 0
        if is_copy(tp) then
			local item_list = {}
			local boss_list = {}
			local hide_list = {}
			 randomcnt =  math.random(1,100)
			 if randomcnt <= tp.monster_probability then
				get_drop_data(drop_count,tp.monster_drop_list,MONSTER_DROP,item_list)
			end
			randomcnt =  math.random(1,100)
			if randomcnt <= tp.monster_probability then
				get_drop_data(boss_count1,tp.boss_drop_list1,BOSS_DROP,item_list)
			end
			randomcnt =  math.random(1,100)
			if randomcnt <= tp.monster_probability then
				get_drop_data(boss_count2,tp.boss_drop_list2,HIDE_BOSS_DROP,item_list)
			end
			if #item_list > 0 then
				local drop_list = {}
				
				for i = 1,#item_list do
					if item_list[i].cnt > 0 then
						drop_list[#drop_list + 1] = item_list[i]
					end
				end
				if #drop_list > 0 then
					ur.item_drop = {}
					ur.item_drop = drop_list
					ur.drop_coin = tp.gold_drop
					ur:send(IDUM_ITEMDROPLIST, {list = drop_list,coin = ur.drop_coin})
				end
			end
			itemdrop.compute_copy_result(ur,mapid)
			ur.info.physical = ur.info.physical - tp.physicalNeed
			if tpgamedata.PhysicalMax > ur.info.physical then
				ur.info.physical_time = shaco.now()//1000
			end
			ur:sync_role_data()
			verify_battle(ur,tp.cheat,mapid)
		end
    end
    ur:db_tagdirty(ur.DB_ROLE_DELAY)
end

REQ[IDUM_MOVEREQ] = function(ur, v)
    scene.move(ur, v)
end

REQ[IDUM_MOVESTOP] = function(ur, v)
    scene.movestop(ur, v)
end

return REQ
