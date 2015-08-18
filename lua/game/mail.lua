--local shaco = require "shaco"
local shaco = require "shaco"
local pb = require "protobuf"
local tbl = require "tbl"
local sfmt = string.format
local ipairs = ipairs
local pairs = pairs
local tonumber = tonumber
local tostring = tostring
local tpmail = require "__tpmail"
local mail_fast = require "mail_fast"
local mail = {}

local function mail_gen()
	return {
		mail_read_time=0,
		mail_id=0,
	}
end

local function old_mail_gen()
	return {
		mail_id = 0,
	}
end

function mail.check_old_mail(old_info,mailid)
	for i = 1,#old_info do
		if old_info[i].mail_id == mailid then
			return true
		end
	end
	return false
end

function mail.new(mailv)
	local mails = mailv
	local now = shaco.now()//1000
	local mail_list = {}
	mails.data = mails.data or {}
	mails.old_info = mails.old_info or {}
	for i=1,#mails.data do
		local tp = tpmail[mails.data[i].mail_id]
		if tp then
			if tp.type == ITEM_MAIL then
				if tp.send_time + tp.unread/1000 < now then
					if mail.check_old_mail(mails.old_info,mails.data[i].mail_id) then
						local old_mail = old_mail_gen()
						old_mail.mail_id = mails.data[i].mail_id
						mails.old_info[#mails.old_info + 1] = old_mail
					end
				else
					mail_list[#mail_list + 1] = mails.data[i]
				end
			else
				if mails.data[i].mail_read_time > tp.send_time then
					if mails.data[i].mail_read_time + tp.read/1000 < now then
						if mail.check_old_mail(mails.old_info,mails.data[i].mail_id) then
							local old_mail = old_mail_gen()
							old_mail.mail_id = mails.data[i].mail_id
							mails.old_info[#mails.old_info + 1] = old_mail
						end
					else
						mail_list[#mail_list + 1] = mails.data[i]
					end
				elseif mails.data[i].mail_read_time == 0 then
					if tp.send_time + tp.unread/1000 < now then
						if mail.check_old_mail(mails.old_info,mails.data[i].mail_id) then
							local old_mail = old_mail_gen()
							old_mail.mail_id = mails.data[i].mail_id
							mails.old_info[#mails.old_info + 1] = old_mail
						end
					else
						mail_list[#mail_list + 1] = mails.data[i]
					end
				end
			end
		end
	end
	mails.data = mail_list
    return mails
end

local function mail_init(ur,mail_list)
	local cur_time = shaco.now()//1000
	local own_list = ur.mail.data
	local old_mails = ur.mail.old_info
	old_mails = old_mails or {}
	local new_list = {}
	for i=1,#mail_list do
		local flag = false
		if mail_list[i].send_time + mail_list[i].unread/1000 > cur_time then
			for j=1,#old_mails do
				if old_mails[j].mail_id and old_mails[j].mail_id == mail_list[i].id then
					flag = true
					break
				end
			end
		else
			flag = true
		end
		if flag == false then
			local __flag = true
			for j =1,#own_list do
				if own_list[j].mail_id == mail_list[i].id then
					__flag = false
					break
				end
			end
			if __flag == true then
				new_list[#new_list + 1] = mail_list[i].id
			end
		end
	end
	return new_list
end

function mail.init(ur)
	local mail_list = ur.mail.data
	local temp_list = {}
	temp_list = mail_init(ur,mail_fast.get_mail_list())
	for i =1,#temp_list do
		local mail_info = mail_gen()
		mail_info.mail_id = temp_list[i]
		mail_list[#mail_list + 1] = mail_info
	end
	if #temp_list > 0 then
		return true
	end
	return false
end

return mail
