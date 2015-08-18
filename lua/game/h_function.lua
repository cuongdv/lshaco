local shaco = require "shaco"
local itemop = require "itemop"
local tpitem = require "__tpitem"
local tbl = require "tbl"
local task = require "task"
local club = require "club"
local card_container = require "card_container"
local mail = require "mail"
local sfmt = string.format
local REQ = {}

local function sync_card_info(ur)
	if ur.cards.sync_partner_flag then
		ur.cards.refresh(ur)
		ur:send(IDUM_CARDPARTNERLIST,{partners = ur.cards.__partner})
		ur.cards.sync_partner_attribute(ur)
		ur.cards.sync_partner_flag = true
	end
end

REQ[IDUM_REQFUNCTION] = function(ur, v)
	if v.func_type == REQ_BAG then  --请求主角界面
		if ur.bit_value & REQ_BAG ~= REQ_BAG then
			itemop.refresh(ur)
			ur.bit_value = ur.bit_value + REQ_BAG
		end
	elseif v.func_type == REQ_WEAPON then   --请求武器界面
		if ur.bit_value & REQ_WEAPON ~= REQ_WEAPON then
			ur.bit_value = ur.bit_value + REQ_WEAPON
			itemop.refresh(ur)
			sync_card_info(ur)
		end
	elseif v.func_type == REQ_SKILL then   --请求技能界面
		if ur.bit_value & REQ_SKILL ~= REQ_SKILL then
			ur.bit_value = ur.bit_value + REQ_SKILL
			itemop.refresh(ur)
		end
	elseif v.func_type == REQ_FORMATION then  --请求阵容
		if ur.bit_value & REQ_FORMATION ~= REQ_FORMATION then
			ur.bit_value = ur.bit_value + REQ_FORMATION
			sync_card_info(ur)
		end
	elseif v.func_type == REQ_CARD then   --请求卡牌界面
		if ur.bit_value & REQ_CARD ~= REQ_CARD then
			ur.bit_value = ur.bit_value + REQ_CARD
			sync_card_info(ur)
		end
	elseif v.func_type == REQ_TRAIN then   --请求训练界面
		if ur.bit_value & REQ_TRAIN ~= REQ_TRAIN then
			ur.bit_value = ur.bit_value + REQ_TRAIN
			sync_card_info(ur)
		end
	elseif v.func_type == REQ_MAIL then  -- 请求邮件界面
		if ur.bit_value & REQ_MAIL ~= REQ_MAIL then
			ur.bit_value = ur.bit_value + REQ_MAIL
			ur:send(IDUM_MAILLIST,{data = ur.mail.data})
		end
	elseif v.func_type == REQ_ECTYPE then  --请求副本界面
		if ur.bit_value & REQ_ECTYPE ~= REQ_ECTYPE then
			ur.bit_value = ur.bit_value + REQ_ECTYPE
			sync_card_info(ur)
		end
	elseif v.func_type == REQ_TASK then --請求任務界面
		if ur.bit_value & REQ_TASK ~= REQ_TASK then
			ur.bit_value = ur.bit_value + REQ_TASK
			ur:send(IDUM_TASKLIST, {info = ur.task.tasks})
		end
	elseif v.func_type == REQ_CLUB then  -- 請求俱樂部界面
		if ur.bit_value & REQ_CLUB ~= REQ_CLUB then
			ur.bit_value = ur.bit_value + REQ_CLUB
			ur:send(IDUM_NOTICECLUBINFO, {info = ur.club})
			sync_card_info(ur)
		end
	end
	ur:send(IDUM_ACKFUNCTION,{func_type = v.func_type})
end

return REQ
