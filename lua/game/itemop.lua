local shaco = require "shaco"
local bag = require "bag"
local tpitem = require "__tpitem"
local math = math
local ipairs = ipairs
local tbl = require "tbl"
local task = require "task"
local tpgodcast = require "__tpgodcast"
local sfmt = string.format
local itemop = {}

local function get_refine_cnt(itemid)
	local indx = 0
	for k,v in pairs(tpgodcast) do
		if v.equipID == itemid then
			for i =1,10 do
				if #v["star"..i] > 0 then
					indx = indx + 1
				end
			end
		end
	end
	return indx
end

local function _equip_gen(tp)
    return {
	    itemid = tp.id,
	    level = 0,
        refinecnt = get_refine_cnt(tp.id),
		star = 0,
	    attack = math.random(tp.minAtk,tp.maxAtk),
	    defense = math.random(tp.minDef,tp.maxDef),
	    magic = math.random(tp.minMagic,tp.maxMagic),
	    magicdef = math.random(tp.minMagicDef,tp.maxMagicDef),
	    hp = math.random(tp.minHP,tp.maxHP),
	    atk_crit = math.random(tp.minAtkCrit,tp.maxAtkCrit),
	    mag_crit = math.random(tp.minMagicCrit,tp.maxMagicCrit),
	    atk_res = math.random(tp.minAtkResistance,tp.maxAtkResistance),
	    mag_res = math.random(tp.minMagicResistance,tp.maxMagicResistance),
	    block = math.random(tp.minBlockRate,tp.maxBlockRate),
	    dodge = math.random(tp.minDodgeRate,tp.maxDodgeRate),
	    mp_reply = math.random(tp.minMPReplyRate,tp.maxMPReplyRate),
	    block_value = math.random(tp.minBlockData,tp.maxBlockData),
	    hits = math.random(tp.minHits,tp.maxHits),
	    hp_reply = math.random(tp.minHPReply,tp.maxHPReply),
		mp = 0,
    }
end	

local function inititemfunc(item, tp)
    if tp.itemType == ITEM_EQUIP then
		
        item.info = _equip_gen(tp)
    end
end

function itemop.init()
    bag.sethandler(inititemfunc)
end

local function _is_mat(tp)
    return tp and tp.itemType == ITEM_MATERIAL
end

-- 获取武器
function itemop.gain_weapon(bag, id)
    return bag:put_bypos(id, 1, EQUIP_WEAPON)
end

function itemop.gain(ur, id, num)
    local tp = tpitem[id]
	if not tp then
		return
	end
	local remain = 0
    if _is_mat(tp) then
		remain = ur.mat:put(id, num)
		ur:item_log(id,remain)
        return remain
    else
		remain = ur.package:put(id, num)
		ur:item_log(id,remain)
		if tp.itemType == 8 then
			task.set_task_progress(ur,37,ur.package:count(id),0)
			task.refresh_toclient(ur, 37)
		end
        return remain
    end
end

function itemop.take(ur, id, num)
    local tp = tpitem[id]
	local remain = 0
    if _is_mat(tp) then
		remain = ur.mat:remove(id, num)
		ur:item_log(id,remain)
        return remain
    else
		remain = ur.package:remove(id, num)
		ur:item_log(id,remain)
        return remain
    end
end

-- dinums: { {id,num},{id,num}, ... }
function itemop.can_gain(ur, idnums)
    local idnums_pkg = {}
    for _, v in ipairs(idnums) do
    	local tp = tpitem[v[1]]
        if not _is_mat(tp) then
            idnums_pkg[#idnums_pkg+1] = v
        end
    end
    if #idnums_pkg > 0 then
        return ur.package:space_enough(idnums_pkg)
    end
    return true
end

local function _refresh(ur, bag)
    local up_itemv = {}
    local function cb(item, flag)
        --if flag == 1 then --up
        --elseif flag == 2 then --add
        --end
        table.insert(up_itemv, item)
    end
    bag:refresh_up(cb)

    if #up_itemv > 0 then
        ur:send(IDUM_ITEMLIST, {bag_type=bag.__type, info=up_itemv})
    end
end

function itemop.refresh(ur)
    _refresh(ur, ur.package);    
    _refresh(ur, ur.equip);
    _refresh(ur, ur.mat);
end

--function itemop.put(bag, id, num)
    --return bag:put(id, num)
--end

--function itemop.put_bypos(bag, id, num, pos)
    --return bag:put_bypos(id, num, pos)
--end

--function itemop.remove(bag, id, num)
    --return bag:remove(id, num)
--end

function itemop.remove_bypos(bag, pos, num)
    return bag:remove_bypos(pos, num)
end

--function itemop.space(bag)
    --return bag:space()
--end

function itemop.exchange(bag1, pos1, bag2, pos2)
    local item1 = bag1:get(pos1)
    local item2 = bag2:get(pos2)
    
    if not item1 and not item2 then
        return 
    end
    if item1 then
        bag2:set(pos2, item1)
    else
        bag2:clr(pos2)
    end
    if item2 then
        bag1:set(pos1, item2)
    else
        bag1:clr(pos1)
    end
    return true
end

function itemop.move(bag1, pos1, bag2)
    local item1 = bag1:get(pos1)
    if not item1 then
        return 
    end
    local pos2  = bag2:find_slot()
    if not pos2 then
        return 
    end
    bag1:clr(pos1)
    bag2:set(pos2, item1)
    return true
end

function itemop.count(ur, id)
    local tp = tpitem[id]
    if _is_mat(tp) then
        return ur.mat:count(id)
    else
        return ur.package:count(id)
    end
end

function itemop.enough(ur, id, num)
    local tp = tpitem[id]
    if _is_mat(tp) then
        return ur.mat:enough(id, num)
    else
        return ur.package:enough(id, num)
    end
end

function itemop.get(bag, pos)
    return bag:get(pos)
end

function itemop.update(bag, pos)
    bag:update(pos)
end

function itemop.getall(bag)
    local l = {}
    for _, v in pairs(bag.__items) do
        if v.tpltid ~= 0 then
            l[#l+1] = v
        end
    end
    return l
end

function itemop.check_equip_task(ur,bag)
	local blue = 0
	local violet = 0 
	local orange = 0
	local max_cnt = EQUIP_MAX
	for i =2,max_cnt do
		local item = bag:get(i)
		if not item then
			return
		end
		local tp = tpitem[item.tpltid]
		if tp.quality >= CARD_BLUE then
			blue = blue + 1
		end
		if tp.quality >= CARD_VIOLET then
			violet = violet + 1
		end
		if tp.quality >= CARD_ORANGE then
			orange = orange + 1
		end
	end
	if blue == max_cnt -1 then
		task.set_task_progress(ur,10,1,0)
		task.refresh_toclient(ur, 10)
	end
	if violet == (max_cnt - 1) then
		task.set_task_progress(ur,11,1,0)
		task.refresh_toclient(ur, 11)
	end
	if orange == (max_cnt - 1) then
		task.set_task_progress(ur,12,1,0)
		task.refresh_toclient(ur, 12)
	end
end

return itemop
