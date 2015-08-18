local shaco = require "shaco"
local tbl = require "tbl"
local sfmt = string.format
local ipairs = ipairs
local pairs = pairs
local tonumber = tonumber
local tostring = tostring
local tpcard = require "__tpcard"
local itemop = require "itemop"
local tpcardbreakthrough = require "__tpcardbreakthrough"
local formula = require "formula"
local card_attribute = {}

local function attribute_gen()
	return {
     	atk=0,
      	def=0,
    	mag=0,
      	mag_def=0,
     	hp=0,
     	mp=0,
      	atk_crit=0,
      	mag_crit=0,
      	atk_res=0,
      	mag_res=0,
      	block=0,
      	dodge=0,
      	mp_reply=0,
      	hits=0,
      	hp_reply=0,
	}
end

function card_attribute.new(cardid,__level,break_through_num)
	local self = attribute_gen()
	local tp = tpcard[cardid]
	if not tp then
		return
	end
	local temp_level = 0
	for k,u in pairs(tpcardbreakthrough) do
		if u.quality == tp.quality and u.breakthrough <= break_through_num  then
			temp_level = temp_level + u.level
		end
	end
	local level = __level + temp_level - 1
	self.hp = tp.hP + level * tp.hPRate
	self.mp = 0
	self.atk = tp.atk + level * tp.atkRate
	self.def = tp.def + level * tp.defRate
	self.mag = tp.magic + level * tp.magicRate
	self.mag_def = tp.magicDef + level * tp.magicDefRate
	self.atk_res = tp.atkResistance + level * tp.atkResistanceRate
	self.mag_res = tp.magicResistance + level * tp.magicResistanceRate
	self.atk_crit = tp.atkCrit + level * tp.atkCritRate
	self.mag_crit = tp.magicCrit + level * tp.magicCritRate
	self.hits = tp.hits + level * tp.hitsRate
	self.block = tp.blockRate + level * tp.blockRateRate
	self.dodge = tp.dodgeRate + level * tp.dodgeRateRate
	self.hp_reply = 0
	self.mp_reply = 0
    setmetatable(self, card_attribute)
    card_attribute.__index = card_attribute
	return self
end

function card_attribute:break_through_compute(cardid,break_through_num)
	local tp = tpcard[cardid]
	if not tp then
		return
	end
	local level = 0
	for k,u in pairs(tpcardbreakthrough) do
		if u.quality == tp.quality and u.breakthrough == break_through_num  then
			level = u.level
		end
	end
    self.hp = self.hp + level * tp.hPRate
	self.mp = 0
	self.atk = self.atk + level * tp.atkRate
	self.def = self.def + level * tp.defRate
	self.mag = self.mag + level * tp.magicRate
	self.mag_def = self.mag_def + level * tp.magicDefRate
	self.atk_res = self.atk_res + level * tp.atkResistanceRate
	self.mag_res = self.mag_res + level * tp.magicResistanceRate
	self.atk_crit = self.atk_crit + level * tp.atkCritRate
	self.mag_crit = self.mag_crit + level * tp.magicCritRate
	self.hits = self.hits + level * tp.hitsRate
	self.block = self.block + level * tp.blockRateRate
	self.dodge = self.dodge + level * tp.dodgeRateRate
	self.hp_reply = self.hp_reply 
	self.mp_reply = 0
end

function card_attribute:level_up_compute(cardid,level)
	local tp = tpcard[cardid]
	if not tp then
		return
	end
	self.hp = self.hp + level * tp.hPRate
	self.mp = 0
	self.atk = self.atk + level * tp.atkRate
	self.def = self.def + level * tp.defRate
	self.mag = self.mag + level * tp.magicRate
	self.mag_def = self.mag_def + level * tp.magicDefRate
	self.atk_res = self.atk_res + level * tp.atkResistanceRate
	self.mag_res = self.mag_res + level * tp.magicResistanceRate
	self.atk_crit = self.atk_crit + level * tp.atkCritRate
	self.mag_crit = self.mag_crit + level * tp.magicCritRate
	self.hits = self.hits + level * tp.hitsRate
	self.block = self.block + level * tp.blockRateRate
	self.dodge = self.dodge + level * tp.dodgeRateRate
	self.hp_reply = self.hp_reply 
	self.mp_reply = 0
end

function card_attribute:compute_break_through(pos,cardid)
	local tp = tpcardbreakthrough[cardid]
	if not tp then
		return
	end

end

function card_attribute:get_Atk()
	if not self.atk then
		return 0
	else
		return self.atk
	end
end

function card_attribute:get_Mag()
	if not self.mag then
		return 0
	else
		return self.mag
	end
end

function card_attribute:get_Def()
	if not self.def then
		return 0
	else
		return self.def
	end
end

function card_attribute:get_MagDef()
	if not self.mag_def then
		return 0
	else
		return self.mag_def
	end
end

function card_attribute:get_HP()
	if not self.hp then
		return 0
	else
		return self.hp
	end
end

function card_attribute:get_MP()
	if not self.mp then
		return 0
	else
		return self.mp
	end
end

function card_attribute:get_AtkCrit()
	if not self.atk_crit then
		return 0
	else
		return self.atk_crit
	end
end

function card_attribute:get_MagCrit()
	if not self.mag_crit then
		return 0
	else
		return self.mag_crit
	end
end

function card_attribute:get_AtkRes()
	if not self.atk_res then
		return 0
	else
		return self.atk_res
	end
end

function card_attribute:get_MagRes()
	if not self.mag_res then
		return 0
	else
		return self.mag_res
	end
end

function card_attribute:get_Block()
	if not self.block then
		return 0
	else
		return self.block
	end
end

function card_attribute:get_Dodge()
	if not self.dodge then
		return 0
	else
		return self.dodge
	end
end

function card_attribute:get_MPReply()
	if not self.mp_reply then
		return 0
	else
		return self.mp_reply
	end
end

function card_attribute:get_Hits()
	if not self.hits then
		return 0
	else
		return self.hits
	end
end

function card_attribute:get_HPReply()
	if not self.hp_reply then
		return 0
	else
		return self.hp_reply
	end
end

function card_attribute:compute_battle()
	local battle_value = formula.get_Combat(self, nil, nil, nil)
	return battle_value
end

function card_attribute:compute_verify()
	local verify_value = self.hp/ math.max(self.atk + self.mag - self.def - self.mag_def,1)
	return verify_value
end

function card_attribute:change_role_attribute(bag,pos) 
	local item = itemop.get(bag, pos)
	if not item then
		return
	end
	local equip_info = item.info
	
	self.hp = self.hp + equip_info.hp 
	self.atk = self.atk + equip_info.attack
	self.def = self.def + equip_info.defense
	self.mag = self.mag + equip_info.magic
	self.mag_def = self.mag_def + equip_info.magicdef
	self.atk_res = self.atk_res + equip_info.atk_res
	self.mag_res = self.mag_res + equip_info.mag_res
	self.atk_crit = self.atk_crit + equip_info.atk_crit
	self.mag_crit = self.mag_crit + equip_info.mag_crit
	self.hits = self.hits + equip_info.hits
	self.block = self.block + equip_info.block
	self.dodge = self.dodge + equip_info.dodge
	self.hp_reply = self.hp_reply + equip_info.hp_reply
	self.mp_reply = self.mp_reply + equip_info.mp_reply
end

function card_attribute:remove_weapon(bag,pos) 
	local item = itemop.get(bag, pos)
	if not item then
		return
	end
	local equip_info = item.info
	self.hp = self.hp - equip_info.hp 
	self.atk = self.atk - equip_info.attack
	self.def = self.def - equip_info.defense
	self.mag = self.mag - equip_info.magic
	self.mag_def = self.mag_def - equip_info.magicdef
	self.atk_res = self.atk_res - equip_info.atk_res
	self.mag_res = self.mag_res - equip_info.mag_res
	self.atk_crit = self.atk_crit - equip_info.atk_crit
	self.mag_crit = self.mag_crit - equip_info.mag_crit
	self.hits = self.hits - equip_info.hits
	self.block = self.block - equip_info.block
	self.dodge = self.dodge - equip_info.dodge
	self.hp_reply = self.hp_reply - equip_info.hp_reply
	self.mp_reply = self.mp_reply - equip_info.mp_reply
end

function card_attribute:weapon_intensify(rate,tp)
	self.atk = self.atk + tp.Atk*rate
    self.def = self.def + tp.Def*rate
    self.mag = self.mag + tp.Magic*rate
    self.mag_def = self.mag_def + tp.MagicDef*rate
    self.hp = self.hp + tp.HP*rate
end

function card_attribute:weapon_godcast(starproperties)
 	for i = 1, #starproperties do
		if starproperties[i][1] == 1 then
			self.hp = self.hp + starproperties[i][2]
		elseif starproperties[i][1] == 2 then
			self.mp = self.mp + starproperties[i][2]
		elseif starproperties[i][1] == 3 then
			self.mp_reply = self.mp_reply + starproperties[i][2]
		elseif starproperties[i][1] == 4 then
			self.atk = self.atk + starproperties[i][2]
		elseif starproperties[i][1] == 5 then
			self.def = self.def + starproperties[i][2]
		elseif starproperties[i][1] == 6 then
			self.mag = self.mag + starproperties[i][2]
		elseif starproperties[i][1] == 7 then
			self.mag_def = self.mag_def + starproperties[i][2]
		elseif starproperties[i][1] == 8 then
			self.hp_reply = self.hp_reply + starproperties[i][2]
		elseif starproperties[i][1] == 9 then
			self.atk_res = self.atk_res + starproperties[i][2]
		elseif starproperties[i][1] == 10 then
			self.mag_res = self.mag_res + starproperties[i][2]
		elseif starproperties[i][1] == 11 then
			self.dodge = self.dodge + starproperties[i][2]
		elseif starproperties[i][1] == 12 then
			self.atk_crit = self.atk_crit + starproperties[i][2]
		elseif starproperties[i][1] == 13 then
			self.mag_crit = self.mag_crit + starproperties[i][2]
		elseif starproperties[i][1] == 14 then
			self.block = self.block + starproperties[i][2]
		elseif starproperties[i][1] == 16 then
			self.hits = self.hits + starproperties[i][2]
		end
 	end
end

return card_attribute
