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

local mail_fast = {}
local mail_list = {}
local update_time = 0

function mail_fast.init()
	local cur_time = shaco.now()//1000
	for k,v in pairs(tpmail) do
		if (v.send_time + v.unread/1000) > cur_time then
			mail_list[#mail_list + 1] = v
		end
	end
	update_time = cur_time
end

function mail_fast.update(now)
	if now/1000 - update_time >= 3600 then
		update_time = now/1000
		local temp_list = {}
		for i =1,#mail_list do
			if mail_list[i].send_time + mail_list[i].unread/1000 > update_time then
				temp_list[#temp_list + 1] = mail_list[i]
			end
		end
		mail_list = temp_list
	end
end

function mail_fast.mail_init(ur)
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

function mail_fast.get_mail_list()
	return mail_list
end

return mail_fast
