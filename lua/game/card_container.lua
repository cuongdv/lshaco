-------------------interface---------------------
--function new(task, task_type, parameter1, parameter2)
--function task_accept(task,id)
------------------------------------------------------------
local shaco = require "shaco"
local warning = shaco.warning
local ipairs = ipairs
local pairs = pairs
local sfmt = string.format
local mfloor = math.floor
local mrandom = math.random
local attribute = require "attribute"
local tbl = require "tbl"
local tpitem = require "__tpitem"
local itemop = require "itemop"
local tpcardlevel = require "__tpcardlevel"
local tpcard = require "__tpcard"
local card_attribute = require "card_attribute"
local card_skill = require "card_skill"
local partner = require "partner"
local bag = require "bag"
local task = require "task"

local function card_gen()
    return {
        cardid=0,
        level=0,
        pos=0,
        break_through_num=0,
        card_exp=0,
        equip={},
        skills={},
    }
end



local function card_init(ur,cardv, tp, cardid, pos)
    cardv.cardid = cardid 
    cardv.pos = pos
    cardv.level = tp.level
    cardv.break_through_num = 0
    cardv.card_exp = 0
    cardv.equip = ur.package.new(BAG_MAX+pos,EQUIP_MAX,cardv.equip)
    cardv.skills = card_skill.create_skill(cardid)
end

local UP_LOAD = 0
local UP_UP  = 1
local UP_ADD = 2

local function tag_up(self, i, flag)
    self.__flags[i] = flag
end

local function init_card(cards)
	local card = {}
	card.cards = cards
end

local card_container = {}

function card_container.new(size, cardv,ur)
    if size <= 0 then
        size = 1
    end
    
    local cards = {}
    local attribute = {}
    local flags = {}
    local partners ={}
	local own_cards = {}
   	 for k, v in ipairs(cardv.list) do
        if v.cardid == 0 then
            warning("card cardid zero")
        elseif v.pos < 0 or v.pos >= size then
            warning("card pos invalid")
        else
            local temp_card = cards[v.pos+1] 
            if temp_card then
                warning("item pos repeat")
            else
                cards[v.pos] = v
                cards[v.pos].equip = ur.package.new(BAG_MAX+v.pos,EQUIP_MAX,cards[v.pos].equip)
                flags[v.pos] = UP_LOAD
                attribute[v.pos] = card_attribute.new(v.cardid,v.level,v.break_through_num)
            end
        end
    end
    partners = partner.new(2,cardv.partners)
    for i=1, size do
        if not cards[i] then
            cards[i] = card_gen()
        end
    end
	own_cards = cardv.own_cards
    local self = {
        __partner = partners,
        __card = {
        	 __cards = cards,
        	 __attributes = attribute
        	 },--init_card(cards[i]),
        __flags = flags,
		__own_cards = own_cards or {},
		__old_partner = {},
		sync_partner_flag = false,
    }
    setmetatable(self, card_container)
    card_container.__index = card_container
    return self
end

function card_container.enough(ur,count)
    local max_cnt = ur.info.cards_size
    local n = 0
    local cards = ur.cards.__card.__cards
   
    for i =1, #cards do
    	local card = cards[i] 
    	if card.cardid ~= 0 then
    		n = n + 1
    	end
    end
    if n + count > max_cnt then
    	return false
    end
    return true
end

function card_container:put(ur,id,count)
    if id <= 0  then
        return 0
    end
    local tp = tpcard[id]
    if not tp then
        return 0
    end
    local cards = self.__card.__cards
	for i =1,count do
		for i=1, #cards do
			local cardv = cards[i]
			if cardv.cardid == 0 then
				tag_up(self, i, UP_ADD)
				card_init(ur,cards[i], tp, id, i)
				self.__card.__attributes[i] = card_attribute.new(id,1,0)
				break
			end
		end
	end
	local own_cards = self.__own_cards
	for i = 1,#own_cards do
		if own_cards[i].cardid == id then
			return 1
		end
	end
	local function own_card_gen ()
		return {
			cardid = 0,
		}
	end
	local own_card_info = own_card_gen()
	own_card_info.cardid = id
	own_cards[#own_cards + 1] = own_card_info
	task.set_task_progress(ur,4,#own_cards,0)
	task.refresh_toclient(ur, 4)
	local violet_cards = {}
	local orange_cards = {}
	for i =1, #own_cards do
		local card_table =  tpcard[own_cards[i].cardid]
		if not card_table then
			shaco.trace(sfmt("card table is error cardid wrong cardid === %d", own_cards[i].cardid))
			return 0
		end
		if card_table.quality == CARD_VIOLET then
			violet_cards[#violet_cards + 1] = own_cards[i].cardid 
		end
		if card_table.quality == CARD_ORANGE then
			orange_cards[#orange_cards + 1] = own_cards[i].cardid 
		end
	end
	task.set_task_progress(ur,8,#violet_cards,0)
	task.refresh_toclient(ur, 8)
	task.set_task_progress(ur,9,#orange_cards,0)
	task.refresh_toclient(ur, 9)
    return 1
end

 local function refresh_up(ur,cb, ...)
    local flags = ur.cards.__flags
    local cards = ur.cards.__card.__cards
    for i, flag in pairs(flags) do
        if flag then
            local cardv = cards[i]
            if cardv then
                cb(cardv, flag, ...)
            end
            flags[i] = nil
        end
    end
end

function card_container.refresh(ur)
    local up_cardv = {}
    local function cb(cardv, flag)
        if flag == 1 then --up
        elseif flag == 2 then --add
        end
        table.insert(up_cardv, cardv)
    end
    refresh_up(ur,cb)
    if #up_cardv > 0 then
    	local cards = {}
    	cards = card_container.get_card_container(up_cardv)
        ur:send(IDUM_CARDLIST, {info=up_cardv})
        for i=1, #cards do
 			cards[i].equip = ur.package.new(BAG_MAX+cards[i].pos,EQUIP_MAX,cards[i].equip)
 		end
		ur.refesh_ladder = 2
    end
end

function card_container.get_target(ur,pos)
	local cards = ur.cards.__card.__cards
	for i=1, #cards do
		local card = cards[i]
		if card.pos == pos then
			return card
		end
	end
	return nil
end

function card_container.equip(ur,target_pos,item_pos)
	local card = card_container.get_target(ur,target_pos)
	if not card then
		return false
	end
	
	local item = itemop.get(ur.package,item_pos)
	if not item  then
		return false
	end
	local tp = tpitem[item.tpltid]
	if not tp then
		return
	end
	return itemop.exchange(card.equip,tp.equipPart,ur.package,item_pos)
end

function card_container.getall(card)
    local l = {}
    for _, v in pairs(card.equip.__items) do
        if v.tpltid ~= 0 then
            l[#l+1] = v
        end
    end
    return l
end

function card_container.get_card_container(cards)
	local cardv = {}
	for i =1,#cards do
		if cards[i].cardid ~= 0 then
			local equip = {}
			equip = itemop.getall(cards[i].equip)
			cardv[#cardv + 1] = cards[i]
			cardv[#cardv].equip = equip
			 
		end
	end
	return cardv
end

 function card_container.set_equip(ur)
 	local cards = ur.cards.__card.__cards
 	for i=1, #cards do
 		cards[i].equip = bag.new(BAG_MAX+cards[i].pos,EQUIP_MAX,cards[i].equip)
 	end
 end

function card_container:clearcard()
	local cards = self.__card.__cards 
	for i = 1,#cards do 
		local card = cards[i]
		if card.cardid ~= 0 then
			card = card_gen()
			card.pos = i
			cards[i] = card
			tag_up(self, i, UP_UP)
		end
	end
end

function card_container:remove(pos)
	local cards = self.__card.__cards 
	for i = 1,#cards do 
		local card = cards[i]
		if card.cardid ~= 0  and card.pos == pos then
			card = card_gen()
			card.pos = pos
			cards[i] = card
			tag_up(self, i, UP_UP)
		end
	end
	for i = 1,#self.__old_partner do
		if self.__old_partner[i].pos == pos then
			self.__old_partner[i].pos = 0
		end
	end
end

function card_container.check_have_equip(card) --weapon except
	local items = card.equip.__items
	if not items then
		return false
	end
	 for _, v in pairs(items) do
        if v.tpltid ~= 0 and v.pos ~= 1 then
            return true
        end
    end
    return false
end

function card_container.card_up_level(ur,materialv)
	local add_exp = 0
	for i = 1,#materialv do
		if materialv[i].cardid ~= 0 then
			local card = card_container.get_target(ur,materialv[i].pos)
			if not card then
				return add_exp
			end
			if card_container.check_have_equip(card) == true then
				return add_exp
			end
		end
	end
	for i = 1,#materialv do
		if materialv[i].cardid ~= 0 then
			local card = card_container.get_target(ur,materialv[i].pos)
			ur.cards:remove(materialv[i].pos)
			local tp = tpcard[materialv[i].cardid]
			if tp then
				add_exp = add_exp + tp.eatExp + tp.eatLevelExp * card.level
			end
		end
	end
	return add_exp
end

local function get_max_exp(level,quality)
	local max_exp = 0
	local tp = tpcardlevel[level + 1]
	if quality == 1 then
		max_exp = tp.White
	elseif quality == 2 then
		max_exp = tp.Green
	elseif quality == 3 then
		max_exp = tp.Blue
	elseif quality == 4 then
		max_exp = tp.Purple
	elseif quality == 5 then
		max_exp = tp.Orange
	end
	return max_exp
end

local function get_exp_level(level,quality,addexp,exp)
	local max_exp = get_max_exp(level,quality)
	local temp_exp = addexp - (max_exp - exp)
	if temp_exp < 0 then
		exp = addexp + exp
	else
		level = level + 1
		level,exp = get_exp_level(level,quality,temp_exp,0)
	end
	return level,exp
end

function card_container.set_exp(ur,card,addexp)
	local flag = false
	local old_level = card.level
	local tp = tpcard[card.cardid]
	if not tp then
		return false
	end
	local level,exp = get_exp_level(card.level,tp.quality,addexp,card.card_exp)
	if level > card.level then
		flag = true
		--compute_role_attribute(ur,card.pos)
	end
	card.level = level
	card.card_exp = exp
	ur.cards.__card.__attributes[card.pos]:level_up_compute(card.cardid,level- old_level)
	return flag
end

function card_container:get(pos)
	local card = {}
	local cards = self.__card.__cards 
	for i = 1,#cards do 
		card = cards[i]
		if card and card.pos == pos then
			break
		end
	end
	return card
end

local function _is_weapon(tp)
    return tp and tp.equipPart == EQUIP_WEAPON
end 

local function remove_item(ur,pos)
	local card = card_container.get_target(ur,pos)
	--compute_card_attribute
	
end

function card_container.equip_weapon(ur,pos,itemid)
	local card = card_container.get_target(ur,pos)
	-- local equip = itemop.getall(card.equip)
	itemop.gain_weapon(card.equip, itemid)
	--[[card.equip = equip
	for i =1,#card.equip do
		local item = card.equip[i]
		if _is_weapon(tpitem[item.itemid]) then
			remove_item(ur,pos)
			itemop.gain_weapon(card.equip, itemid)
		end
	end]]
	
end

function card_container.set_level(ur,pos,level)
	local card = card_container.get_target(ur,pos)
	local old_level = card.level
	card.level = level
	--shaco.trace(sfmt("old_level ==== %d----------------- card.level == %d ...", old_level,card.level))
	ur.cards.__card.__attributes[pos]:level_up_compute(card.cardid,level- old_level)
	ur:db_tagdirty(ur.DB_CARD)
	ur:send(IDUM_GMSETLEVEL, {info = card})
end

function card_container.set_card_level(ur,cardid,level)
	local cards = ur.cards.__card.__cards
	for i=1, #cards do
		local card = cards[i]
		if card.cardid == cardid then
			card.level = level
		end
	end
	
	--card_container.refresh(ur)
	ur:db_tagdirty(ur.DB_CARD)
end

function card_container.get_max_partner_battle(ur)
	local function partner_info()
		return {
			pos = 0,
			battle_value = 0,
		}
	end
	local partner_list = {}
	local partners = ur.cards.__partner
	for i = 1,#partners do
		local info = partner_info()
		if partners[i].pos > 0 then
			info.battle_value = ur.cards.__card.__attributes[partners[i].pos]:compute_battle()
			info.pos = partners[i].pos
		end
		partner_list[#partner_list + 1] = info
	end
	if partner_list[1].battle_value >= partner_list[2].battle_value then
		return  partner_list[1].pos, partner_list[1].battle_value
	else
		return  partner_list[2].pos, partner_list[2].battle_value
	end	
end

local function partner_attribute_gen()
	return {
		pos = 0,
		attribute = {},
	}
end

local function check_is_own(pos,old_partner)
	for i =1,#old_partner do
		if old_partner[i].pos == pos then
			return true
		end
	end
	return false
end

function card_container.sync_partner_attribute(ur)
	local attribute_list = {}
	local partners = ur.cards.__partner
	for i = 1,#partners do
		if partners[i].pos > 0 then
			if not check_is_own(partners[i].pos,ur.cards.__old_partner) then
				local partner_attribute = partner_attribute_gen()
				partner_attribute.pos = partners[i].pos
				partner_attribute.attribute = ur.cards.__card.__attributes[partners[i].pos]
				attribute_list[#attribute_list + 1] = partner_attribute
			end
		end
	end
	ur:send(IDUM_SYNPARTNERATTRIBUTE,{attributes = attribute_list})
end

function card_container.set_old_partner(cards,pos)
	local function old_partner_gen()
		return {
			pos = 0,
		}
	end
	local flag = false
	for i = 1,#cards.__old_partner do
		if cards.__old_partner[i] == pos then
			flag = true
		end
	end
	if not flag then
		cards.__old_partner[#cards.__old_partner + 1] = pos
	end
end

function card_container.get_partner_battle(ur)
	local partners = ur.cards.__partner
	local total_value = 0
	for i = 1,#partners do
		if partners[i].pos > 0 then
			
			local partner_attribute = ur.cards.__card.__attributes[partners[i].pos]
			if partner_attribute then
				local battle_value = partner_attribute:compute_battle()
				total_value = total_value + battle_value
			else
				shaco.trace(sfmt("-partners[i].pos ==== %d ...", partners[i].pos))
			end
		end
	end
	return total_value
end

function card_container.sync_partner_weapon_attribute(ur,pos)
	local attribute_list = {}
	local partners = ur.cards.__partner
	for i = 1,#partners do
		if partners[i].pos > 0 and pos == partners[i].pos then
			local partner_attribute = partner_attribute_gen()
			partner_attribute.pos = partners[i].pos
			partner_attribute.attribute = ur.cards.__card.__attributes[partners[i].pos]
			attribute_list[#attribute_list + 1] = partner_attribute
		end
	end
	ur:change_role_battle_value()
	ur:send(IDUM_SYNPARTNERATTRIBUTE,{attributes = attribute_list})
end

return card_container
