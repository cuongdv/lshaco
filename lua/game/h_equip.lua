local shaco = require "shaco"
local tpitem = require "__tpitem"
local tpequip = require "__tpequip"
local tpforge = require "__tpforge"
local tpgodcast = require "__tpgodcast"
local tpequipalloy = require "__tpequipalloy"
local tpgamedata = require "__tpgamedata"
local tpcard = require "__tpcard"
local itemop = require "itemop"
local tostring = tostring
local tbl = require "tbl"
local card_container = require "card_container"
local task = require "task"
local sfmt = string.format

local REQ = {}

REQ[IDUM_REQWEAPONINFO] = function(ur, v)
	itemop.refresh(ur)
	ur.cards.refresh(ur)
	ur:send(IDUM_ACKWEAPONINFO, {})
end

local function change_attribute(rate,equip,tp)
    equip.level = equip.level + rate
    equip.attack = equip.attack + tp.Atk*rate
    equip.defense = equip.defense + tp.Def*rate
    equip.magic = equip.magic + tp.Magic*rate
    equip.magicdef = equip.magicdef + tp.MagicDef*rate
    equip.hp = equip.hp + tp.HP*rate
    return equip
end

REQ[IDUM_EQUIPINTENSIFY] = function(ur, v)
	local flag = false
	local tp_equip = {}
	local bag = ur:getbag(v.bag_type)
	if v.pos >= 1000 then
		local pos = v.pos - 1000
		local card = card_container.get_target(ur,pos)
		bag = card.equip
	end
    if not bag then
        return SERR_TYPE_ERROR
    end
    local item = itemop.get(bag,EQUIP_WEAPON)
    if not item then
        return SERR_ITEM_NOT_EXIST
    end
    local tp = tpitem[item.tpltid]
    if not tp then
    	return SERR_ERROR_LABEL
    end 
    if tp.equipPart ~= EQUIP_WEAPON then
    	return SERR_EQUIP_NOT_INTENSIFY
    end
	for k, u in ipairs(tpequip) do
		if u.EquipID == item.tpltid then
			tp_equip = u
			break
		end
	end
	if not tp_equip then
        return SERR_ITEM_NOT_EXIST
    end
	if item.info.level >= ur.base.level then
		return
	end
    if item.info.level >= tp_equip.MaxLevel then
    	return SERR_WEAPON_INTENSIFY_MAX_LEVEL
    end
    if ur:coin_take(tp_equip.Price) == false then
		return SERR_COIN_NOT_ENOUGH
	end 
	item.info = change_attribute(1,item.info,tp_equip)
	if v.pos >= 1000 then 
		ur.cards.__card.__attributes[v.pos - 1000]:weapon_intensify(1,tp_equip)
	else
		ur:weapon_intensify(1,tp_equip)
		itemop.update(bag, EQUIP_WEAPON)
	end
	itemop.refresh(ur)
	
	ur:db_tagdirty(ur.DB_ROLE)
	if v.pos >= 1000 then 
		local pos = v.pos - 1000
		local card = card_container.get_target(ur,pos)	
		local equip = itemop.getall(card.equip)
		card.equip = equip
		ur:send(IDUM_UPDATE_CARD_WEAPON, {handle_type = INTENSIFY,info=card}) 	
		card.equip = ur.package.new(BAG_MAX+card.pos,EQUIP_MAX,card.equip)
		ur:db_tagdirty(ur.DB_CARD)
		card_container.sync_partner_weapon_attribute(ur,pos)
	else
		task.set_task_progress(ur,5,item.info.level,0)
		task.refresh_toclient(ur, 5)
		ur:change_attribute(ur)
		ur:send(IDUM_SUCCESSRETURN,{success_type = INTENSIFY}) 
		ur:db_tagdirty(ur.DB_ITEM)
	end
end

local function check_material_enough(ur,bag,materialarray)
	local templist = {}
	for j = 1,#materialarray do
		--reward_gen()
		templist[j] = {itemid = 0, itemcnt = 0}
		templist[j].itemid = (materialarray[j][1])
    	templist[j].itemcnt = (materialarray[j][2])
    	if not itemop.enough(ur, templist[j].itemid, templist[j].itemcnt) then
    		return false
    	end
	end
	for i =1 ,#templist do
		itemop.take(ur, templist[i].itemid, templist[i].itemcnt)
	end
	
	return true
end

local function check_own_equip(ur,equipid)
	local items = ur.equip.items
	for i, item in ipairs(items) do
        if item.tpltid == equipid then
        	return item.info.level
        end
    end
    return 0
end

REQ[IDUM_EQUIPFORGE] = function(ur, v) 
	local needRole = 0
	local bag = ur:getbag(v.bag_type)
	if v.targetid >= 1000 then
		local pos = v.targetid - 1000
		local card = card_container.get_target(ur,pos)
		bag = card.equip
		needRole = card.cardid
	end
    if not bag then
        return SERR_TYPE_ERROR
    end
    local bag_mat = ur:getbag(BAG_MAT)
    if not bag_mat then
    	return SERR_TYPE_ERROR
    end
	local tp = {}
	local __tp = tpforge[v.drawingid]
	if __tp then
		for i =1,#__tp do
			local t = __tp[i]
			if t and t.needRole == needRole then
				tp = t
				break
			end
		end
	end
	local rate = 0
	if tp.needOccupation then
		if v.targetid >= 1000 then
			local pos = v.targetid - 1000
			local card = card_container.get_target(ur,pos)
			local tp_card = tpcard[card.cardid]
			if tp.needOccupation ~= tp_card.occupation then
				return SERR_NOT_NEED_OCCUPATION
			end
			if tp.needRole ~= card.cardid then
				return SERR_NOT_NEED_SEX
			end 
		else
			if tp.needOccupation ~= ur.base.race then
				return SERR_NOT_NEED_OCCUPATION
			end
			if tp.needRole ~= 0 then
				return SERR_NOT_NEED_SEX
			end 
		end
	end
	local baseequip = tp.needEquip
	local level = 0
	local item = {}
	if baseequip ~= 0 then
		item = itemop.get(bag, EQUIP_WEAPON)
		if not item then
			return SERR_NOT_OWN_BASE_WEAPON
		end
		level = item.info.level
	end
	if ur:coin_enough(tp.Price) == false then 
		return SERR_COIN_NOT_ENOUGH
	end
	local materialarray = tp.itemNeed
	if check_material_enough(ur,bag_mat,materialarray) == false then
		return SERR_MATERIAL_NOT_ENOUGH
	end
	ur:coin_take(tp.Price)
	if v.targetid < 1000 then
		ur.info.attribute:remove_weapon(bag,EQUIP_WEAPON)
	else
		ur.cards.__card.__attributes[v.targetid - 1000]:remove_weapon(bag,EQUIP_WEAPON)
	end
	itemop.remove_bypos(bag,EQUIP_WEAPON,1)
	itemop.gain_weapon(bag, tp.outputEquip)
	if v.targetid < 1000 then
		ur.info.attribute:change_role_attribute(bag,EQUIP_WEAPON)
	else
		ur.cards.__card.__attributes[v.targetid - 1000]:change_role_attribute(bag,EQUIP_WEAPON)
	end
	rate = level - tp.levelMinus
	itemop.refresh(ur)
	ur:db_tagdirty(ur.DB_ROLE)
	ur:db_tagdirty(ur.DB_ITEM)
	task.set_task_progress(ur,23,0,0)
	task.refresh_toclient(ur, 23)
	local tp_item = tpitem[tp.outputEquip]
	--if tp
	if v.targetid >= 1000 then 
		local pos = v.targetid - 1000
		local card = card_container.get_target(ur,pos)	
		local equip = itemop.getall(card.equip)
		card.equip = equip
		ur:send(IDUM_UPDATE_CARD_WEAPON, {handle_type = FORGE,info=card}) 	
		card.equip = ur.package.new(BAG_MAX+card.pos,EQUIP_MAX,card.equip)
		card_container.sync_partner_weapon_attribute(ur,pos)
		ur:db_tagdirty(ur.DB_CARD)
	else
		ur:change_attribute(ur)
		ur:send(IDUM_SUCCESSRETURN,{success_type = FORGE}) 
	end
	
end

local function change_some_attribute(starproperties,info)
 	for i = 1, #starproperties do
 		if starproperties[i][1] == 1 then
 			info.hp = info.hp + starproperties[i][2]
 		elseif starproperties[i][1] == 2 then
			info.mp = info.mp + starproperties[i][2]
 		elseif starproperties[i][1] == 3 then
			info.mp_reply = info.mp_reply + starproperties[i][2]
 		elseif starproperties[i][1] == 4 then
 			info.attack = info.attack + starproperties[i][2]
 		elseif starproperties[i][1] == 5 then
 			info.defense = info.defense + starproperties[i][2]
 		elseif starproperties[i][1] == 6 then
 			info.magic = info.magic + starproperties[i][2]
 		elseif starproperties[i][1] == 7 then
 			info.magicdef = info.magicdef + starproperties[i][2]
 		elseif starproperties[i][1] == 8 then
			info.hp_reply = info.hp_reply + starproperties[i][2]
 		elseif starproperties[i][1] == 9 then
			info.atk_res = info.atk_res + starproperties[i][2]
 		elseif starproperties[i][1] == 10 then
			info.mag_res = info.mag_res + starproperties[i][2]
		elseif starproperties[i][1] == 11 then
			info.dodge = info.dodge + starproperties[i][2]
		elseif starproperties[i][1] == 12 then
			info.atk_crit = info.atk_crit + starproperties[i][2]
		elseif starproperties[i][1] == 13 then
			info.mag_crit = info.mag_crit + starproperties[i][2]
		elseif starproperties[i][1] == 14 then
			info.block = info.block + starproperties[i][2]
		elseif starproperties[i][1] == 15 then
			info.block_value = info.block_value + starproperties[i][2]
		elseif starproperties[i][1] == 16 then
			info.hits = info.hits + starproperties[i][2]
 		end
 	end
 	return info
end

REQ[IDUM_EQUIPGODCAST] = function(ur, v)
	local bag = ur:getbag(v.bag_type)
	if v.pos >= 1000 then
		local pos = v.pos - 1000
		local card = card_container.get_target(ur,pos)
		bag = card.equip
	end
	
    if not bag then
        return SERR_TYPE_ERROR
    end
    local bag_mat = ur:getbag(BAG_MAT)
    if not bag_mat then
    	return SERR_TYPE_ERROR
    end
	local item = itemop.get(bag, EQUIP_WEAPON)
	if not item then
		return SERR_NOT_OWN_BASE_WEAPON
	end
	local star = item.info.star + 1
	local tp = {}
	for k, u in pairs(tpgodcast) do
		if u.equipID == item.tpltid then
			tp = u
			break
		end
	end
	if not tp then
		return SERR_ERROR_LABEL
	end
	if item.info.refinecnt <= 0 then
		return SERR_GODCAST_MAX_COUNT
	end
	local targetstar = tp["star"..tostring(star)]
	if check_material_enough(ur,bag_mat,tp["star"..tostring(star)]) == false then
		return SERR_MATERIAL_NOT_ENOUGH
	end		
	item.info = change_some_attribute(tp["star"..tostring(star).."properties"],item.info)
	item.info.star = star
	item.info.refinecnt = item.info.refinecnt - 1
	if v.pos >= 1000 then 
		ur.cards.__card.__attributes[v.pos - 1000]:weapon_godcast(tp["star"..tostring(star).."properties"])
	else
		ur.info.attribute:weapon_godcast(tp["star"..tostring(star).."properties"])
		itemop.update(bag, EQUIP_WEAPON)
	end
	itemop.refresh(ur)
	ur:db_tagdirty(ur.DB_ITEM)
	if v.pos >= 1000 then 
		local pos = v.pos - 1000
		local card = card_container.get_target(ur,pos)	
		local equip = itemop.getall(card.equip)
		card.equip = equip
		ur:send(IDUM_UPDATE_CARD_WEAPON, {handle_type = GODCAST,info=card}) 	
		card.equip = ur.package.new(BAG_MAX+card.pos,EQUIP_MAX,card.equip)
		card_container.sync_partner_weapon_attribute(ur,pos)
		ur:db_tagdirty(ur.DB_CARD)
	else
		ur:change_attribute(ur)
		ur:send(IDUM_SUCCESSRETURN,{success_type = GODCAST})  
	end	
end

local function splitstringinfo(szfullstring,szseparator)
	local nfindstartindex = 1
	local nsplitindex = 1
	local nsplitarray = {}
	while true do
		local nfindlastindex = find(szfullstring, szseparator, nfindstartindex)
		if not nfindlastindex then
			nsplitarray[nsplitindex] = sub(szfullstring, nfindstartindex, len(szfullstring))
			break
		end
		nsplitarray[nsplitindex] = sub(szfullstring, nfindstartindex, nfindlastindex - 1)
		nfindstartindex = nfindlastindex + len(szseparator)
		nsplitindex = nsplitindex + 1
	end
	return nsplitarray;
end

local function better_quality(quality)
	local itemlist = {}
	for k, v in pairs(tpitem) do
		if v.quality == quality then
			itemlist[#itemlist + 1] = k
		end
	end
	if #itemlist == 0 then
		return
	end
	local index = math.random(#itemlist)
	return itemlist[index]
end

local function check_item_quality(items)
	local quality = 0
	for i =1,#items do
		local tp = tpitem[items[i].tpltid]
		if i == 1 then
			quality = tp.quality
		end
		if quality ~= tp.quality then
			return false,quality
		end
	end
	return true,quality
end

REQ[IDUM_EQUIPCOMPOSE] = function(ur, v)
	local bag = ur:getbag(BAG_PACKAGE)
    if not bag then
        return SERR_TYPE_ERROR
    end
	local items = {}
	for i =1,#v.posv do
		local item = itemop.get(bag, v.posv[i])
		if not item then
			return SERR_ITEM_NOT_EXIST
		end
		items[#items+1] = item
	end
	if #items ~= 5 then
		return SERR_MATERIAL_NOT_ENOUGH
	end
	local flag,item_quality = check_item_quality(items)
	if flag == false then
		return SERR_MATERIAL_SAME_QUALITY
	end
	
	local flag = 1
	local randvalue = math.random(1,10000)
--	shaco.trace(sfmt("user randvalue === %d create role ...", randvalue))
	if item_quality == GREEN then
		if randvalue > tpgamedata.GreenEquipment then
			flag = 2
		end
	elseif item_quality == BLUE then
		if randvalue > tpgamedata.BlueEquipment then
			flag = 2
		end
	elseif item_quality == YELLOW then
		if randvalue > tpgamedata.YellowEquipment then
			flag = 2
		end
	elseif item_quality == PURPLE then
		if randvalue > tpgamedata.PurpleEquipment then
			flag = 2
		end
	elseif item_quality == ORANGE then
		if randvalue > tpgamedata.OrangeEquipment then
			flag = 2
		end
	end
	local tps = {}
	local max_weight = 0
	for k,v in ipairs(tpequipalloy) do
		if v.quality == item_quality + 1 and ur.base.level >= v.minlevel and ur.base.level <= v.maxlevel then
			tps[#tps + 1] = v
			max_weight = max_weight + v.Weights*10
		end
	end
	local random_weight = math.random(1,max_weight)
	local compose_target = {}
	local temp_weight = 0
	for i = 1,#tps do
		temp_weight = temp_weight + tps[i].Weights*10
		if temp_weight >= random_weight then
			compose_target = tps[i]
			break
		end
	end
	for i =1, #items do
		itemop.take(ur, items[i].tpltid, 1)
	end
	if flag == 1 then
		itemop.gain(ur, compose_target.EquipID, 1)
	end
	itemop.refresh(ur)
	task.set_task_progress(ur,44,0,0)
	task.refresh_toclient(ur, 44)
	ur:db_tagdirty(ur.DB_ITEM)
	ur:send(IDUM_EQUIPCOMPOSERESULT, {itemid = compose_target.EquipID,result = flag})
end

return REQ
