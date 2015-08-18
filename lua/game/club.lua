--local shaco = require "shaco"
local shaco = require "shaco"
local pb = require "protobuf"
local tbl = require "tbl"
local sfmt = string.format
local ipairs = ipairs
local pairs = pairs
local tonumber = tonumber
local tostring = tostring
local tpclub = require "__tpclub"
local tpclub_treasure = require "__tpclub_treasure"
local clubs = {}

local function clubs_gen()
	return {
		crops = {},
		card_framgent = {},
		club_refresh_cnt =0,
		violet_framgent =0,
		orange_framgent =0,
		score =0,
		last_refresh_time =0,
	}
end

local function corp_gen()
	return {
		corpsid =0,
		corps_state =0,
	}
end

local function card_framgent_info_gen()
	return {
		card_framgent_id =0,
		count =0,
	}
end

local function check_crop_exsit(id,crops)
	for i =1,#crops do
		if crops[i].corpsid == id then
			return false
		end
	end
	return true
end

function clubs.update(ur,login)
	local now = shaco.now()//1000
	local curtime=os.date("*t",now)
	local level = ur.base.level
	if curtime.hour >= 5 then
		if not login then
			if ur.across_day ~= 1 then
				return
			else
				ur.across_day = 0 
			end
		end
		local total_weight = 0
		local clubs = {}
		for k,v in pairs(tpclub) do
			if v.user_level[1][1] <= level and v.user_level[1][2] >= level then
				if v.club_hardness == 1 then
					clubs[#clubs + 1] = v
					total_weight = total_weight + v.club_probability 
				end
			end
		end
		local random_weight = math.random(0,total_weight)
		local weight = 0
		local crop_list = {}
		for j =1,5 do
			for i =1,#clubs do
				weight = weight + clubs[i].club_probability
				if weight >= random_weight then
					if check_crop_exsit(clubs[i].id,crop_list) == true then
						local crop = corp_gen()
						crop.corpsid = clubs[i].id
						crop_list[#crop_list + 1] = crop
						break
					end
				end
			end
		end
		local club_info = ur.club 
		local club = clubs_gen()
		club.crops = crop_list
		club.last_refresh_time = now
		club.card_framgent = club_info.card_framgent
		club.club_refresh_cnt = 0
		club.violet_framgent = club_info.violet_framgent
		club.orange_framgent = club_info.orange_framgent
		club.score = club_info.score
		ur.club = club
		ur:db_tagdirty(ur.DB_CLUB)
	elseif curtime.hour < 5 and login then
		ur.across_day = 1
	end
end

function clubs.new(clubv,level) 
	local clubs = {}	
	if #clubv ~= 0 then
		return false,clubv
	end
	local total_weight = 0
	for k,v in pairs(tpclub) do
		if v.user_level[1][1] <= level and v.user_level[1][2] >= level then
			if v.club_hardness == 1 then
				clubs[#clubs + 1] = v
				total_weight = total_weight + v.club_probability 
			end
		end
	end
	local random_weight = math.random(0,total_weight)
	local weight = 0
	local crop_list = {}
	for j =1,5 do
		for i =1,#clubs do
			weight = weight + clubs[i].club_probability
			if weight >= random_weight then
				if check_crop_exsit(clubs[i].id,crop_list) == true then
					local crop = corp_gen()
					crop.corpsid = clubs[i].id
					crop_list[#crop_list + 1] = crop
					break
				end
			end
		end
	end
	local club = clubs_gen()
	club.crops = crop_list
    return true,club
end

local function check_club_refresh(ur,pos)
	local club = ur.club.crops[pos]
	if club.corps_state == 0 then
		return false,club
	end
	return true,club
end

function clubs.refresh_club(ur,club_refresh_cnt)
	local clubs = {} 
	local total_weight = 0
	local random_weight = 0
	local weight = 0
	local crop_list = {}
	local level = ur.base.level
	local flag,club_info = check_club_refresh(ur,1)
	if flag == false then
		for k,v in pairs(tpclub) do
			if v.user_level[1][1] <= level and v.user_level[1][2] >= level then
				if v.club_hardness == 3 then
					clubs[#clubs + 1] = v
					total_weight = total_weight + v.club_probability 
				end
			end
		end
		random_weight = math.random(0,total_weight)
		for i =1,#clubs do
			weight = weight + clubs[i].club_probability
			if weight >= random_weight then
				local crop = corp_gen()
				crop.corpsid = clubs[i].id
				crop_list[#crop_list + 1] = crop
				break
			end
		end
	else
		crop_list[#crop_list + 1] = club_info
	end	
	for j=1,2 do
		total_weight = 0
		clubs = {}
		flag,club_info = check_club_refresh(ur,1+j)
		if flag == false then
			for k,v in pairs(tpclub) do
				if v.user_level[1][1] <= level and v.user_level[1][2] >= level then
					if v.club_hardness == 1 or v.club_hardness == 2 and check_crop_exsit(v.id,crop_list) == true then
					clubs[#clubs + 1] = v
						total_weight = total_weight + v.club_probability 
					end
				end
			end
			random_weight = math.random(0,total_weight)
			weight = 0
			for i =1,#clubs do
				weight = weight + clubs[i].club_probability
				if weight >= random_weight then
					local crop = corp_gen()
					crop.corpsid = clubs[i].id
					crop_list[#crop_list + 1] = crop
					break
				end
			end
		else
			crop_list[#crop_list + 1] = club_info
		end
	end	
	for j=1,2 do
		total_weight = 0
		clubs = {}
		flag,club_info = check_club_refresh(ur,3+j)
		if flag == false then
			for k,v in pairs(tpclub) do
				if v.user_level[1][1] <= level and v.user_level[1][2] >= level then
					if v.club_hardness == 1 and check_crop_exsit(v.id,crop_list) == true then
						clubs[#clubs + 1] = v
						total_weight = total_weight + v.club_probability 
					end
				end
			end
			random_weight = math.random(0,total_weight)
			weight = 0
			for i =1,#clubs do
				weight = weight + clubs[i].club_probability
				if weight >= random_weight then
					if check_crop_exsit(clubs[i].id,crop_list) == true then
						local crop = corp_gen()
						crop.corpsid = clubs[i].id
						crop_list[#crop_list + 1] = crop
						break
					end
				end
			end
		else
			crop_list[#crop_list + 1] = club_info
		end	
	end
	local club = clubs_gen()
	local cur_club = ur.club
	club.crops = crop_list
	club.club_refresh_cnt = club_refresh_cnt
	club.card_framgent = cur_club.card_framgent
	club.violet_framgent = cur_club.violet_framgent
	club.orange_framgent = cur_club.orange_framgent
	club.score = cur_club.score
    return club
end

function clubs.add_fragment(ur,fragmentid,count)
	local club = ur.club
	local flag = false
	if fragmentid == 1000 then
		club.violet_framgent = club.violet_framgent + count
		return
	elseif fragmentid == 2000 then
		club.orange_framgent = club.orange_framgent + count
		return
	end
	for i =1,#club.card_framgent do 
		if club.card_framgent[i].card_framgent_id == fragmentid then
			club.card_framgent[i].count = club.card_framgent[i].count + count
			flag = true
			break
		end
	end
	if flag == false then
		for i =1,#club.card_framgent do 
			if club.card_framgent[i].card_framgent_id == 0 then
				club.card_framgent[i].count = count
				club.card_framgent[i].card_framgent_id = fragmentid
				flag = true
				break
			end
		end
	end
	if flag == false then
		local fragment_info = card_framgent_info_gen()
		fragment_info.card_framgent_id = fragmentid
		fragment_info.count = count
		club.card_framgent = club.card_framgent or {}
		club.card_framgent[#club.card_framgent + 1] = fragment_info
	end
	ur:db_tagdirty(ur.DB_CLUB)
end

return clubs
