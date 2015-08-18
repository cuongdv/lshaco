local shaco = require "shaco"
local itemop = require "itemop"
local tpitem = require "__tpitem"
local tbl = require "tbl"

local REQ = {}

REQ[IDUM_REQITEMINFO] = function(ur, v)
	itemop.refresh(ur)
	ur:send(IDUM_ACKITEMINFO, {})
end

REQ[IDUM_EQUIP] = function(ur, v)
    local bag1 = ur:getbag(v.bag_type)
    if not bag1 then
        return
    end
    local item = itemop.get(bag1,v.pos)
    local tp = tpitem[item.tpltid]
    if not tp then
        return
    end
	print(tp.occup)
	if tp.occup ~= 1 and tp.occup & ur.base.race ~= ur.base.race then
		return SERR_NOT_NEED_OCCUPATION
	end
    if tp.equipPart < EQUIP_WEAPON or tp.equipPart > EQUIP_BRACELET then
    	return
    end
    local bag2 = ur:getbag(BAG_EQUIP)
    if v.bag_type == BAG_PACKAGE then
   		if itemop.exchange(bag2,tp.equipPart,bag1,v.pos) then
			ur:change_attribute(ur)
        	itemop.refresh(ur)
       	 	ur:db_tagdirty(ur.DB_ITEM)
			itemop.check_equip_task(ur,bag2)
    	end
    end
end

REQ[IDUM_UNEQUIP] = function(ur, v)
	local bag1 = ur:getbag(v.bag_type)
    if not bag1 then
        return
    end
    local bag2 = ur:getbag(BAG_PACKAGE)
    if itemop.move(bag1,v.pos,bag2) then
		ur:change_attribute(ur)
    	itemop.refresh(ur)
        ur:db_tagdirty(ur.DB_ITEM)
    end
end

REQ[IDUM_ITEMSALE] = function(ur, v)
    local updated = false
    local got_money = 0
    local bag = ur:getbag(v.bag_type)

    for _, one in ipairs(v.posnumv) do
        local pos, count = one.int1, one.int2
        local item = itemop.get(bag, pos)
        if item then
            local tp = tpitem[item.tpltid]
            if tp then
                if count == 0 then
                    count = item.stack
                end
                local count = itemop.remove_bypos(bag, pos, count)
                if count > 0 then
                    got_money = got_money + tp.sellPrice*count
                    updated = true
                end
            end
        end
    end
    if updated then
        ur:coin_got(got_money)
        itemop.refresh(ur)
		ur:sync_role_data()
        ur:db_tagdirty(ur.DB_ROLE)
        ur:db_tagdirty(ur.DB_ITEM)
    end
end

return REQ
