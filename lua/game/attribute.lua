local shaco = require "shaco"
local tbl = require "tbl"
local sfmt = string.format
local ipairs = ipairs
local pairs = pairs
local tonumber = tonumber
local tostring = tostring
local tprole = require "__tprole"
local tpcard = require "__tpcard"
local tpdazzle_fragment = require "__tpdazzle_fragment"
local tpdazzle = require "__tpdazzle"
local itemop = require "itemop"
local formula = require "formula"
local bag = require "bag"
local tpequip = require "__tpequip"

local attributes = {}

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

function attributes:passive_skill_attr(ur)
	for i =1,#ur.info.skills do
		
	end
end

function attributes:equip_add(ur,pos)
	local bag = ur:getbag(BAG_EQUIP)
    if not bag then
        return 
    end
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

function attributes:dazzle_fragment_add(ur,id)
	local tp = tpdazzle_fragment[id]
	if not tp then
		return
	end
	self.hp = self.hp + v.Parameter1
	self.mp = self.mp + v.Parameter2
	self.atk = self.atk + v.Parameter3
	self.def = self.def + v.Parameter4
	self.mag = self.mag + v.Parameter5
	self.mag_def = self.mag_def + v.Parameter6
	self.atk_res = self.atk_res + v.Parameter7
	self.mag_res = self.mag_res + v.Parameter8
	self.atk_crit = self.atk_crit + v.Parameter9
	self.mag_crit = self.mag_crit + v.Parameter10
end

function attributes:dazzle_add(ur,dazzle_type,dazzle_level)
	for k, v in pairs(tpdazzle) do
		if v.Type == dazzle_type and v.Level == dazzle_level then
			self.hp = self.hp + v.Parameter1
			self.hp = self.hp + self.hp * v.Percent1 / 100
			self.mp = self.mp + v.Parameter2
			self.mp = self.mp + self.mp * v.Percent2 / 100
			self.atk = self.atk + v.Parameter3
			self.atk = self.atk + self.atk * v.Percent3 / 100
			self.def = self.def + v.Parameter4
			self.def = self.def + self.def * v.Percent4 / 100
			self.mag = self.mag + v.Parameter5
			self.mag = self.mag + self.mag * v.Percent5 / 100
			self.mag_def = self.mag_def + v.Parameter6
			self.mag_def = self.mag_def + self.mag_def * v.Percent6 / 100
			self.atk_res = self.atk_res + v.Parameter7
			self.atk_res = self.atk_res + attribute.atk_res * v.Percent7 / 100
			self.mag_res = self.mag_res + v.Parameter8
			self.mag_res = self.mag_res + self.mag_res * v.Percent8 / 100
			self.atk_crit = self.atk_crit + v.Parameter9
			self.atk_crit = self.atk_crit + self.atk_crit * v.Percent9 / 100
			self.mag_crit = self.mag_crit + v.Parameter10
			self.mag_crit = self.mag_crit + self.mag_crit * v.Percent10 / 100
		end
	end
end

function attributes:dazzle_attr(ur)	
	for i =1, #ur.info.dazzles do 
		if ur.info.dazzles[i].dazzle_use == 1 then
			self:dazzle_add(ur,ur.info.dazzles[i].dazzle_type,ur.info.dazzles[i].dazzle_level)
			for j =1,#ur.info.dazzles[i].fragment do
				self:dazzle_fragment_add(ur.info.dazzles[i].fragment[j].fragmentid)
			end
		end
	end
end 

function attributes:add_attribute(ur)
	for i=1,EQUIP_MAX do
		self:equip_add(ur,i)
	end
	self:passive_skill_attr(ur)
	self:dazzle_attr(ur)
end

function attributes:compute_attribute(race,level)
	for k, v in pairs(tprole) do
		if v.occup == race and v.level == level then
			self.hp = v.hp
			self.mp = v.mp
			self.atk = v.atk
			self.def = v.def
			self.mag = v.magic
			self.mag_def = v.magicDef
			self.atk_res = v.atkResistance
			self.mag_res = v.magicResistance
			self.atk_crit = v.atkCrit
			self.mag_crit = v.magicCrit
			self.hits = v.hits
			self.block = v.blockRate
			self.dodge = v.dodgeRate
			self.hp_reply = v.HPReply
			self.mp_reply = v.MPReplyRate
		end
	end
end

function attributes.new(race,level)
	local self = attribute_gen()
	for k, v in pairs(tprole) do
		if v.occup == race and v.level == level then
			self.hp = v.hp
			self.mp = v.mp
			self.atk = v.atk
			self.def = v.def
			self.mag = v.magic
			self.mag_def = v.magicDef
			self.atk_res = v.atkResistance
			self.mag_res = v.magicResistance
			self.atk_crit = v.atkCrit
			self.mag_crit = v.magicCrit
			self.hits = v.hits
			self.block = v.blockRate
			self.dodge = v.dodgeRate
			self.hp_reply = v.HPReply
			self.mp_reply = v.MPReplyRate
		end
	end
    setmetatable(self, attributes)
    attributes.__index = attributes
    
	return self
end

function attributes.compute_battle(ur)
	local battle_value = 0
	local attribute = ur.info.attribute		
	return battle_value
end

function attributes:get_Atk()
	if not self.atk then
		return 0
	else
		return self.atk
	end
end

function attributes:get_Mag()
	if not self.mag then
		return 0
	else
		return self.mag
	end
end

function attributes:get_Def()
	if not self.def then
		return 0
	else
		return self.def
	end
end

function attributes:get_MagDef()
	if not self.mag_def then
		return 0
	else
		return self.mag_def
	end
end

function attributes:get_HP()
	if not self.hp then
		return 0
	else
		return self.hp
	end
end

function attributes:get_MP()
	if not self.mp then
		return 0
	else
		return self.mp
	end
end

function attributes:get_AtkCrit()
	if not self.atk_crit then
		return 0
	else
		return self.atk_crit
	end
end

function attributes:get_MagCrit()
	if not self.mag_crit then
		return 0
	else
		return self.mag_crit
	end
end

function attributes:get_AtkRes()
	if not self.atk_res then
		return 0
	else
		return self.atk_res
	end
end

function attributes:get_MagRes()
	if not self.mag_res then
		return 0
	else
		return self.mag_res
	end
end

function attributes:get_Block()
	if not self.block then
		return 0
	else
		return self.block
	end
end

function attributes:get_Dodge()
	if not self.dodge then
		return 0
	else
		return self.dodge
	end
end

function attributes:get_MPReply()
	if not self.mp_reply then
		return 0
	else
		return self.mp_reply
	end
end

function attributes:get_Hits()
	if not self.hits then
		return 0
	else
		return self.hits
	end
end

function attributes:get_HPReply()
	if not self.hp_reply then
		return 0
	else
		return self.hp_reply
	end
end

function attributes:compute_verify()
	local verify_value = self:get_HP()/ math.max(self:get_Atk() + self:get_Mag() - self:get_Def() - self:get_MagDef(),1)
	return verify_value
end

function attributes:get_battle_value()
	local battle_value = formula.get_Combat(self, nil, nil, nil)
	return battle_value
end

function attributes:change_role_attribute(bag,pos) 
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

function attributes:remove_weapon(bag,pos) 
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

function attributes:weapon_intensify(rate,tp)
	self.atk = self.atk + tp.Atk*rate
    self.def = self.def + tp.Def*rate
    self.mag = self.mag + tp.Magic*rate
    self.mag_def = self.mag_def + tp.MagicDef*rate
    self.hp = self.hp + tp.HP*rate
end

function attributes:weapon_godcast(starproperties)
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

return attributes
