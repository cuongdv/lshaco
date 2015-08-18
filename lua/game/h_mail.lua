local shaco = require "shaco"
local tpmail = require "__tpmail"
local tostring = tostring
local sfmt = string.format
local mail = require "mail"
local tbl = require "tbl"
local itemop = require "itemop"
local club = require "club"
local card_container = require "card_container"
local ladder = require "ladder"

local REQ = {}

local function old_info_gen()
	return {
		mail_id = 0,
	}
end

local function get_mail_item(ur,tp)
	local item_flag = false
	local fragment_flag = false
	local card_flag = false
	local honor_flag = false
	for i=1,5 do
		if tp["Item"..i.."_type"] == ITEM_TYPE then
			item_flag = true
			itemop.gain(ur,tp["Item"..i.."_id"],tp["Item"..i.."_count"])
		elseif tp["Item"..i.."_type"] == CARD_FRAGMENT then
			fragment_flag = true
			club.add_fragment(ur,tp["Item"..i.."_id"],tp["Item"..i.."_count"])
		elseif tp["Item"..i.."_type"] == CARD_TYPE then
			local cards = ur.cards
			if cards:put(ur,tp["Item"..i.."_id"],tp["Item"..i.."_count"]) > 0 then
				card_flag = true
			end
		elseif tp["Item"..i.."_type"] == HONOR_TYPE then
			honor_flag = true
			ladder.add_honor(ur,tp["Item"..i.."_id"],tp["Item"..i.."_count"])
		end
			
	end
	if item_flag == true then
		itemop.refresh(ur)
		ur:db_tagdirty(ur.DB_ITEM)
	end
	if card_flag == true then
		card_container.refresh(ur)
		ur:db_tagdirty(ur.DB_CARD)
	end
end

REQ[IDUM_REQMAILREWARD] = function(ur, v)
	local mail_list = ur.mail.data
	local target_mail = nil
	local temp_mails = {}
	for i=1,#mail_list do
		if mail_list[i].mail_id == v.mail_id then
			target_mail = mail_list[i]
		else
			temp_mails[#temp_mails + 1] = mail_list[i]
		end
	end
	if not target_mail then
		return
	end
	shaco.trace(sfmt("v.mail_id === %d  e ...", v.mail_id))
	local tp = tpmail[v.mail_id]
	if not tp then
		return
	end
	ur.mail.old_info = ur.mail.old_info or {}
	if tp.type == ITEM_MAIL then
		if mail.check_old_mail(ur.mail.old_info,v.mail_id) then
			return SERR_ALREADY_TAKE_MAIL_REWARD
		end
	end
	local now = shaco.now()//1000
	if tp.send_time + tp.unread/1000 < now then
		return
	end
	if tp.type == ITEM_MAIL then --item_mail
		if tp.glod > 0 then
			ur:coin_got(tp.glod)
		end
		if tp.diamond > 0 then
			ur:gold_take(tp.diamond)
		end
		get_mail_item(ur,tp)
		local temp_list = {}
		for i=1,#mail_list do
			if mail_list[i].mail_id ~= v.mail_id then
				temp_list[#temp_list + 1] = mail_list[i]
			end
		end
		mail_list  = {}
		mail_list = temp_list
	elseif tp.type == WORD_MAIL then --word_mail
		target_mail.mail_read_time = math.ceil(now)
	end
	
	
	local old_mail_info = old_info_gen()
	old_mail_info.mail_id = v.mail_id
	if tp.type == WORD_MAIL then
		if not mail.check_old_mail(ur.mail.old_info,v.mail_id) then
			ur.mail.old_info[#ur.mail.old_info + 1] = old_mail_info
		end
	else
		ur.mail.data = temp_mails
		ur.mail.old_info[#ur.mail.old_info + 1] = old_mail_info
	end
	ur:db_tagdirty(ur.DB_MAIL)
	ur:send(IDUM_ACKMAILREWARD,{mail_id = v.mail_id,mail_read_time = now})
end

REQ[IDUM_ONEKEYGETMAILREWARD] = function(ur, v)
	local mail_list = ur.mail.data
	local mail_word_list = {}
	for i=1,#mail_list do
		local mail_id = mail_list[i].mail_id
		local tp = tpmail[mail_list[i].mail_id]
		if tp then
			if tp.type == ITEM_MAIL then
				if not mail.check_old_mail(ur.mail.old_info,mail_id) then
					get_mail_item(ur,tp)
					local old_mail_info = old_info_gen()
					old_mail_info.mail_id = mail_id
					ur.mail.old_info[#ur.mail.old_info + 1] = old_mail_info
				end
			else
				mail_word_list[#mail_word_list + 1] = mail_list[i]
			
			end
		end
	end
	ur.mail.data = mail_word_list
	ur:db_tagdirty(ur.DB_MAIL)
	ur:send(IDUM_ONEKEYSUCCESS,{result = 1})
end

REQ[IDUM_REQMAILINFO] = function(ur, v)
	ur:send(IDUM_MAILLIST,{data = ur.mail.data})
end

return REQ
