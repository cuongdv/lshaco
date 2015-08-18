local shaco = require "shaco"
local tonumber = tonumber
local floor = math.floor
local tbl = require "tbl"
local REQ = require "req"
local CTX = require "ctx"
local scene = require "scene"
local task = require "task"
local itemop = require "itemop"
local card_container = require "card_container"
local mystery = require "mystery"
local club = require "club"
local ladder  = require "ladder"
local mail_fast = require "mail_fast"
local task_fast = require "task_fast"
local tpclub = require "__tpclub"
local attribute = require "attribute"
local sfmt = string.format
local find = string.find
local sub = string.sub
local len = string.len
local GM = {}
local md5 = require"md5"

GM.help = function(ur)
	if ur.info.gm_level <= 0 then
		return
	end
    local t = {}
    for k, _ in ipairs(GM) do
        table.insert(t, k)
    end
    local content = table.concat(t, "\r\n")
end

GM.getitem = function(ur, args)
    if #args < 3 then
        return
    end
	if ur.info.gm_level <= 0 then
		return
	end
    local pkg = ur.package
    local tpltid = tonumber(args[2])
    local count  = tonumber(args[3])
    if itemop.gain(ur, tpltid, count) > 0 then
        itemop.refresh(ur)
        ur:db_tagdirty(ur.DB_ITEM)
    end
end

GM.getcoin = function(ur, args)
    if #args < 2 then
        return
    end
	if ur.info.gm_level <= 0 then
		return
	end
    local count = tonumber(args[2])
    if ur:coin_got(count) ~= 0 then
        ur:db_tagdirty(ur.DB_ROLE)
    end
end

GM.changescene = function(ur, args)
    if #args < 2 then
        return
    end
	if ur.info.gm_level <= 0 then
		return
	end
    local tpid = tonumber(args[2])
    scene.enter(ur, tpid)
end

GM.taskacc = function(ur, args)
	if #args < 2 then
        return
    end
	if ur.info.gm_level <= 0 then
		return
	end
    local taskid = floor(tonumber(args[2]))
    local tempv = {taskid = taskid}
	REQ[IDUM_ACCEPTTASK](ur, tempv)
end

GM.taskfinish = function(ur, args)
	if #args < 2 then
        return
    end
	if ur.info.gm_level <= 0 then
		return
	end
    local taskid = floor(tonumber(args[2]))
    if task.finish(ur,taskid) == true then	
        ur:db_tagdirty(ur.DB_TASK)
        ur:send(IDUM_TASKLIST, {info = ur.task.tasks})
    end
end

GM.taskreward = function(ur, args)
	if #args < 2 then
        return
    end
	if ur.info.gm_level <= 0 then
		return
	end
    local taskid = floor(tonumber(args[2]))
    local tempv = {taskid = taskid}
    REQ[IDUM_GETREWARD](ur, tempv)
end


GM.equipcast = function(ur,args)
	if #args < 2 then
        return
    end
	if ur.info.gm_level <= 0 then
		return
	end
    local itemid = floor(tonumber(args[2]))
    local star = floor(tonumber(args[3]))
    local tempv = {id = itemid, star = star}
    REQ[IDUM_EQUIPGODCAST](ur, tempv)
end

GM.equipinfy = function(ur, args)
	if #args < 2 then
        return
    end
	if ur.info.gm_level <= 0 then
		return
	end
    local itemid = floor(tonumber(args[2]))
    local tempv = {itemid = itemid}
    REQ[IDUM_EQUIPINTENSIFY](ur, tempv)
end

GM.equipforge = function(ur, args)
	if #args < 2 then
        return
    end
	if ur.info.gm_level <= 0 then
		return
	end
    local itemid = floor(tonumber(args[2]))
    local tempv = {itemid = itemid}
    REQ[IDUM_EQUIPFORGE](ur, tempv)
end

GM.equipcompose = function(ur, args)
	if #args < 2 then
        return
    end
	if ur.info.gm_level <= 0 then
		return
	end
    local tempv = {szmaterial = args[2]}
    REQ[IDUM_EQUIPCOMPOSE](ur, tempv)
end

GM.passectype = function(ur, args)
	if #args < 3 then
        return
    end
	if ur.info.gm_level <= 0 then
		return
	end
    local ectypeid = floor(tonumber(args[2]))
	local hp = floor(tonumber(args[3]))
    local tempv = {ectypeid = ectypeid,user_hp = hp}
	REQ[IDUM_PASSECTYPE](ur, tempv)
end


GM.getcard = function(ur, args)
    if #args < 2 then
        return
    end
	if ur.info.gm_level <= 0 then
		return
	end
    local cards = ur.cards
    local cardid = tonumber(args[2])
    if not card_container.enough(ur,1) then
    	return
    end
    if cards:put(ur,cardid,1) > 0 then
        cards.refresh(ur)
        ur:db_tagdirty(ur.DB_CARD)
    end
end

GM.equip = function(ur, args)
	if #args < 3 then
        return
    end
	if ur.info.gm_level <= 0 then
		return
	end
	local __type = floor(tonumber(args[2]))
	local pos = floor(tonumber(args[3]))
	local tempv = {bag_type = __type,pos = pos}
	REQ[IDUM_EQUIP](ur,tempv)
end

GM.cardequip = function(ur, args)
	if #args < 4 then
        return
    end
	if ur.info.gm_level <= 0 then
		return
	end
    local bag_type = floor(tonumber(args[2]))
	local itempos = floor(tonumber(args[3]))
	local targetpos = floor(tonumber(args[4]))
	local tempv = {bag_type = bag_type,pos = itempos,card_pos = targetpos}
	REQ[IDUM_EQUIPCARD](ur, tempv)
end

GM.cardup = function(ur, args)
	if #args < 5 then
        return
    end
	if ur.info.gm_level <= 0 then
		return
	end
    local function card_up_gen()
    	return {
    		targetid=0,
   			tarpos=0,	
   			material={},
    	}
    end
    local function material_gen()
    	return {
    		cardid = 0,
    		pos = 0,
    	}
    end
    local targetid = floor(tonumber(args[2]))
    local targetpos = floor(tonumber(args[3]))
    local materials = {}
    local material = material_gen()
    material.cardid = floor(tonumber(args[4]))
    material.pos = floor(tonumber(args[5]))
    materials[#materials+1] = material
    local card_up = card_up_gen()
    card_up.targetid = targetid
    card_up.tarpos = targetpos
    card_up.material = materials
    REQ[IDUM_CARDUP](ur,card_up)
end

GM.cardclear = function(ur, args)
	if ur.info.gm_level <= 0 then
		return
	end
	ur.cards:clearcard()
	ur.cards.refresh(ur)
    ur:db_tagdirty(ur.DB_CARD)
end

GM.cardpartner = function(ur, args)
	if #args < 2 then
        return
    end
	if ur.info.gm_level <= 0 then
		return
	end
    local pos = floor(tonumber(args[2]))
    local posv = {}
    posv[#posv + 1] = pos
    REQ[IDUM_CARDPARTNER](ur, {pos = posv})
end

GM.buyitem = function(ur, args)
    if #args < 3 then
        return
    end
	if ur.info.gm_level <= 0 then
		return
	end
    local buy_type = floor(tonumber(args[2]))
    local id = floor(tonumber(args[3]))
    REQ[IDUM_SHOPBUYITEM](ur,{buy_type = buy_type,random_id = id})
end

GM.copydrop = function(ur, args)
    if #args < 2 then
        return
    end
	if ur.info.gm_level <= 0 then
		return
	end
    local mapid = floor(tonumber(args[2]))
    REQ[IDUM_SCENEENTER](ur, {mapid = mapid})
end

GM.dazzlecompose = function(ur, args)
	 if #args < 3 then
        return
    end
	if ur.info.gm_level <= 0 then
		return
	end
	local _type = floor(tonumber(args[2]))
	local _level = floor(tonumber(args[3]))
	REQ[IDUM_USEDAZZLE](ur,{dazzle_type = _type,dazzle_level = _level})
end

GM.fraequip = function(ur, args)
	 if #args < 4 then
        return
    end
	if ur.info.gm_level <= 0 then
		return
	end
	local _type = floor(tonumber(args[2]))
	local _level = floor(tonumber(args[3]))
	local _id = floor(tonumber(args[4]))
	REQ[IDUM_EQUIPDAZZLEFRAGMENT](ur,{fragmentid = _id,dazzle_type = _type,dazzle_level = _level})
end

GM.fracompose = function(ur, args)
	if #args < 4 then
        return
    end
	if ur.info.gm_level <= 0 then
		return
	end
	local _type = floor(tonumber(args[2]))
	local _level = floor(tonumber(args[3]))
	local _id = floor(tonumber(args[4]))
	REQ[IDUM_COMPOSEFRAGMENT](ur,{dazzle_type = _type,dazzle_level = _level,fragmentid = _id})
end

GM.mysteryitem = function(ur, args)
	if #args < 3 then
		return
	end
	if ur.info.gm_level <= 0 then
		return
	end
	local itemid = floor(tonumber(args[2]))
	local count = floor(tonumber(args[3]))
	REQ[IDUM_REQBUYMYSTERYITEM](ur,{itemid = itemid,cnt = count})
end

GM.refreshmystery = function(ur, args)
	if ur.info.gm_level <= 0 then
		return
	end
	if ur:gold_take(200) == false then
		return 
	else
		mystery.refresh_mystery_shop(ur)
	end
end

GM.addcardfragment = function(ur, args)
	if #args < 3 then
		return
	end
	if ur.info.gm_level <= 0 then
		return
	end
	local fragmentid = floor(tonumber(args[2]))
	local count = floor(tonumber(args[3]))
	club.add_fragment(ur,fragmentid,count)
end
GM.refreshclub = function(ur, args)
	if ur.info.gm_level <= 0 then
		return
	end
	if ur.info.gm_level <= 0 then
		return
	end
	local club = club.refresh_club(ur,1)
	ur.club = club
end

GM.enterclub = function(ur, args)
	if #args < 2 then
		return
	end
	if ur.info.gm_level <= 0 then
		return
	end
	local clubid =  floor(tonumber(args[2]))
	REQ[IDUM_REQENTERCLUBSCENE](ur,{clubid = clubid})
end

GM.costscore = function(ur, args)
	if #args < 3 then
		return
	end
	if ur.info.gm_level <= 0 then
		return
	end
	local clubid =  floor(tonumber(args[2]))
	local type = floor(tonumber(args[3]))
	REQ[IDUM_REQEXTRACTREWARD](ur, {clubid = clubid,use_score_type = type})
end

GM.exchangecard = function(ur, args)
	if #args < 4 then
		return
	end
	if ur.info.gm_level <= 0 then
		return
	end
	local cardid =  floor(tonumber(args[2]))
	local buy_type = floor(tonumber(args[3]))
	local card_count = floor(tonumber(args[4]))
	REQ[IDUM_REQEXCHANGECARD](ur, {cardid = cardid,buy_type = buy_type,card_count = card_count})
end

GM.addscore = function(ur, args)
	if #args < 2 then
		return
	end
	if ur.info.gm_level <= 0 then
		return
	end
	local score =  floor(tonumber(args[2]))
	ur.club.score = ur.club.score + score
	ur:db_tagdirty(ur.DB_CLUB)
end

GM.enterladder = function(ur,args)
	ladder.enter_ladder(ur,1)
end

GM.addladderscore = function(ur, args)
	if #args < 2 then
		return
	end
	if ur.info.gm_level <= 0 then
		return
	end
	local score =  floor(tonumber(args[2]))
	ladder.add_ladder_score(ur,score)
end

GM.reduceladdscore = function(ur, args)
	if #args < 2 then
		return
	end
	if ur.info.gm_level <= 0 then
		return
	end
	local score =  floor(tonumber(args[2]))
	ladder.reduce_ladder_score(ur,score)
end

GM.updaterank = function(ur,args)
	if ur.info.gm_level <= 0 then
		return
	end
	ladder.update_ranking(ur)
end

GM.reqrank = function(ur, args)
	if ur.info.gm_level <= 0 then
		return
	end
	ladder.req_ladder_rank(ur)
end

GM.openmystery = function(ur, args)
	if ur.info.gm_level <= 0 then
		return
	end
	mystery.random_mystery_shop(ur,100)
end

GM.mailinit = function(ur,args)
	if ur.info.gm_level <= 0 then
		return
	end
	mail_fast.init()
end

GM.lastrank = function(ur, args)
	if #args < 2 then
		return
	end
	if ur.info.gm_level <= 0 then
		return
	end
	local last_rank =  floor(tonumber(args[2]))
	ladder.changelastrank(ur,last_rank)
end

GM.refreshladder = function(ur, args)
	if ur.info.gm_level <= 0 then
		return
	end
	REQ[IDUM_REQBUYCHALLENGECNT](ur, {})
end

GM.opponent = function(ur, args)
	if ur.info.gm_level <= 0 then
		return
	end
	REQ[IDUM_REQSEARCHOPPONENT](ur, {})
end

GM.setlevel = function(ur, args)
	if #args < 2 then
		return
	end
	if ur.info.gm_level <= 0 then
		return
	end
	local level =  floor(tonumber(args[2]))
	ur:set_level(level)
end

GM.changeweapon = function(ur, args)
	if #args < 2 then
		return
	end
	if ur.info.gm_level <= 0 then
		return
	end
	local weaponid =  floor(tonumber(args[2]))
	local bag = ur:getbag(BAG_EQUIP)
	itemop.remove_bypos(bag,EQUIP_WEAPON,1)
	itemop.gain_weapon(bag, weaponid)
	itemop.refresh(ur)
	ur:db_tagdirty(ur.DB_ITEM)
end

GM.addhonor = function(ur,args)
	if #args < 2 then
		return
	end
	if ur.info.gm_level <= 0 then
		return
	end
	local honor =  floor(tonumber(args[2]))
	ladder.add_ladder_honor(ur,honor)
end

local function splitstringinfo(szfullstring,szseparator)
	local nfindstartindex = 1
	local nsplitindex = 1
	local nsplitarray = {}
	while true do
		local nfindlastindex = find(szfullstring, szseparator, nfindstartindex)
		if not nfindlastindex then
			nsplitarray[nsplitindex] = sub(szfullstring, nfindstartindex, len(szfullstring))
			break
		end
		nsplitarray[nsplitindex] = sub(szfullstring, nfindstartindex, nfindlastindex - 1)
		nfindstartindex = nfindlastindex + len(szseparator)
		nsplitindex = nsplitindex + 1
	end
	return nsplitarray;
end

GM.items = function(ur, args)
	if ur.info.gm_level <= 0 then
		return
	end
	local items = {}
	local cnts = {}
	for i=2,#args do
		if i % 2 == 0 then
			items[#items + 1] = args[i]
		else
			cnts[#cnts + 1] = args[i]
		end
	end
	for i =1,#items do
		itemop.gain(ur, tonumber(items[i]), tonumber(cnts[i]))
	end
	itemop.refresh(ur)
    ur:db_tagdirty(ur.DB_ITEM)
end

GM.test = function(ur,args)
	--local func_type =  floor(tonumber(args[2]))
	--REQ[IDUM_REQFUNCTION](ur, {func_type = func_type})
	--ur:x_log_role_cheat(1005,0)
	--[[local test = 15
	local value = string.format("%0.2f", test) 
	print(value)
	shaco.trace(sfmt("use  ----------create role ===%s..",value))
	local cur_time = os.date("%Y-%m-%d %X", shaco.now()//1000)
	print(cur_time)
	shaco.trace(sfmt("use  ----------create role ===%s..",cur_time))
	
	local back_value = "amount=1.0&channel_number=000023&enhanced_sign=15bd6dbff98c484da25d2d57233fd831&game_user_id=25000&order_id=PB79892015050814315695636&order_type=80&pay_status=1&pay_time=2015-05-08+14%3A31%3A56&private_data=%E8%B4%AD%E4%B9%B0%E4%B8%80%E4%B8%AA%E5%85%83%E5%AE%9D&product_count=1&product_id=0&product_name=gold&server_id=2&user_id=88185&sign=f9ed409ee124f840071ca1a4a8916709"
	local AppId= "100010"
	local Act= "1"
	local ProductName="%e6%98%9f%e9%99%85%e8%bf%b7%e8%88%aaDemo"
	local ConsumeStreamId= "1-10001-20101214233421-1-6422"
	local CooOrderSerial="a258337465ff4e85b78b2c23d7046098"
	local Uin= "155451276"
	local GoodsId= "80370"
	local GoodsInfo= "X1000%e6%88%98%e6%96%97%e6%9c%ba"
	local GoodsCount= "1"
	local OriginalMoney= "0.01"
	local OrderMoney= "0.01"
	local Note= "%e6%88%98%e6%96%97%e6%9c%ba"
	local PayStatus= "1"
	local CreateTime="2010-12-14 23:34:21"
	local strSource = ""..AppId..Act..ProductName..ConsumeStreamId..CooOrderSerial..Uin..GoodsId..GoodsInfo..GoodsCount..OriginalMoney..OrderMoney..Note..PayStatus..CreateTime
	shaco.trace(sfmt("use  ----------create ----- strSource ===%s..",strSource))
	local strSource1 = "1.000002315bd6dbff98c484da25d2d57233fd83125000PB798920150508143156956368012015-05-08 14:31:56购买一个元宝10gold288185"
	local strSource2 = "524fae82ed5dcd04ba087ed4c98d25f3NmVkYWFiN2VkZjRkZmE1YWEyYjQ"
	shaco.trace(sfmt("use  ----------create ----- strSource1 ===%s..",strSource1))
	shaco.trace(sfmt("use  ----------create ----- md5.sumhexa(strSource1) ===%s..",md5.sumhexa(strSource1)))
    --local Sign=15bd6dbff98c484da25d2d57233fd831
	local nsplitarray = splitstringinfo(back_value,"&")
	tbl.print(nsplitarray, "=============init nsplitarray", shaco.trace)
	--4fcab6de6f3ee0b629f6c3002e42cfc1
--	4fcab6de6f3ee0b629f6c3002e42cfc1]]
end

GM.ladderover = function(ur,args)
	if ur.info.gm_level <= 0 then
		return
	end
	REQ[IDUM_NOTICEBATTLEOVER](ur,{battle_result = 1})
end

GM.setcardlvl = function(ur,args)
	if #args < 3 then
		return
	end
	if ur.info.gm_level <= 0 then
		return
	end
	local tarpos = floor(tonumber(args[2]))
	local level =  floor(tonumber(args[3]))
	card_container.set_level(ur,tarpos,level)
end

GM.setcardlevel = function(ur,args)
	if #args < 3 then
		return
	end
	if ur.info.gm_level <= 0 then
		return
	end
	local cardid = floor(tonumber(args[2]))
	local level =  floor(tonumber(args[3]))
	card_container.set_card_level(ur,cardid,level)
end

GM.addrobot = function(ur,args)
	if ur.info.gm_level <= 0 then
		return
	end
	local cnt = floor(tonumber(args[2]))
	scene.addrobot(ur,cnt)
end

GM.setgmlevel = function(ur,args)
	ur.info.gm_level = 1
end

return GM
