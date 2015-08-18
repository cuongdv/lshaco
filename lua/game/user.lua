local shaco = require "shaco"
local pb = require "protobuf"
local tbl = require "tbl"
local bor  = bit32.bor
local band = bit32.band
local bnot = bit32.bnot
local lshift = bit32.lshift
local tinsert = table.insert
local sfmt = string.format
local floor = math.floor
local CTX = require "ctx"
local MSG_RESNAME = require "msg_resname"
local bag = require "bag"
local scene = require "scene"
local task = require "task"
local ectype = require "ectype"
local tpcreaterole = require "__tpcreaterole"
local skills = require "skill"
local attributes = require "attribute"
local itemop = require "itemop"
local card_container = require "card_container"
local partner = require "partner"
local tpgamedata = require "__tpgamedata"
local dazzles = require "dazzle"
local mystery = require "mystery"
local tprole = require "__tprole"
local club = require "club"
local ladder = require "ladder"
local config = require "config"
local mail = require "mail"

local user = {
    DB_ROLE=1,
    DB_ITEM=2,
    DB_TASK=4,
    DB_ROLE_DELAY=8,
    DB_CARD=16,
	DB_CLUB = 32,
	DB_LADDER = 64,
	DB_MAIL = 128,

    -- status
    US_LOGIN = 1,
    US_WAIT_CREATE = 2,
    US_WAIT_SELECT = 3,
    US_GAME = 4,
}

local function sync_role_gen()
	return {
	    coin=0,
    	gold=0,
    	exp=0,
   	    level=0,
		physical=0,
		battle = 0,
	}
end

local function item_drop_gen()
	return {
		itemid = 0,
		cnt = 0,
	}
end

local function turn_card_reward_gen()
	return {
		itemid = 0,
		cnt = 0,
		__type = 0,
	}
end

local function role_info_gen()
	return {
		mapid = 0,
		posx = 0,
		posy = 0,
		coin = 0,
		gold = 0,
		package_size = 0,
        exp = 0,
        refresh_time = 0,
        oid = 0,
		ectype = {},
		skills = {},
		attribute = nil,
        map_entertime=0,
        last_city=0,
        cards_size=0,
		dazzles = {},
		mystery = nil,
		physical = tpgamedata.Physical,
		physical_time = 0,
		gm_level = 0,
	}
end

local function container_gen()
	return {
    	list={},
    	partners={},
    	}
end

function user.new(connid, status, acc, rl)
    local self = {
        connid = connid,
        status = status,
        acc = acc,
        roles = rl,
        base = nil,
        info = nil,
        package = nil,
        equip=nil,
        mat=nil,
        task = nil,
        cards = nil,
        db_dirty_flag = 0,
		item_drop = {},
		turn_card_reward = {},
		battle_value = 0,
		club = nil,
		refesh_ladder = 0,
		rank_update = 0,
		mail = nil,
		drop_coin = 0,
		across_day = 0,
		battle_verify = false,
		bit_value = 0,
		five_rank_update = 0,
    }
    setmetatable(self, user)
    user.__index = user
    return self
end

local OBJID_ALLOC = ROLE_STARTOID
local function objid_gen()
    if OBJID_ALLOC < ROLE_STARTOID then
        OBJID_ALLOC = ROLE_STARTOID
    end
    OBJID_ALLOC = OBJID_ALLOC+1
    return OBJID_ALLOC
end

function user:init(...)
    local tt = {...}
    local info, item, taskv, cardv,clubv, mailv = ... 
    local new_role = false
    if not info then
        info = role_info_gen()
        new_role = true
	end
	
	info.ectype = ectype.new(info.ectype)
    local item = item or {}
    local item_pkg = item.package or {}
    local item_equip = item.equip or {}
    local item_mat = item.mat or {}
	
    if info.package_size < tpgamedata.PlayerBackpack then
        info.package_size = tpgamedata.PlayerBackpack
    end
    if info.cards_size < tpgamedata.CardBackpack then
        info.cards_size = tpgamedata.CardBackpack
    end
   
    if info.last_city == 0 then
        info.last_city = 1
    end
    info.mapid = info.last_city
    info.oid = objid_gen()
	if not info.mystery then
		--if info.mystery.strat_time - os.time() > 500 then
			--info.mystery = nil
		--end
	end
    self.info = info
    self.package = bag.new(BAG_PACKAGE, info.package_size, item_pkg)
    self.equip = bag.new(BAG_EQUIP, EQUIP_MAX, item_equip)
    self.mat = bag.new(BAG_MAT, BAG_MAT_SIZE, item_mat)
    
   
    taskv = taskv or {}
    self.task = task.new(TASK_SYSTEM, taskv)
	
    --info.partners = partner.new(info.partner_size,info.partners)
	info.dazzles = dazzles.new(info.dazzles) 
	local flag = 1
	info.skills,flag = skills.new(self.base.tpltid,info.skills)
	if flag == 1 then
		self:db_tagdirty(self.DB_ROLE)
	end
	 if not cardv then
    	cardv = container_gen()
    end
	self.cards = card_container.new(info.cards_size,cardv,self)
    if new_role then
        local tp = tpcreaterole[self.base.tpltid]
        if tp then
            for _, v in ipairs(tp.Item) do
                itemop.gain(self, v[1], v[2])
            end
            if tp.Weapon > 0 then
                itemop.gain_weapon(self.equip, tp.Weapon)
				--info.attribute:change_role_attribute(self.equip,EQUIP_WEAPON)
            end
            self:db_tagdirty(self.DB_ITEM)
            info.coin = tp.Money
            info.gold = tp.Emoney
        end
        -- just test
        task.first_accept(self)
        self.cards:put(self,100,1)
        self:db_tagdirty(self.DB_ROLE)
        
        self:db_tagdirty(self.DB_TASK)
        self:db_tagdirty(self.DB_CARD)
    end	
    
	local club_flg = false
	clubv = clubv or {}
	club_flg,self.club = club.new(clubv,self.base.level)
	if club_flg == true then
		self:db_tagdirty(self.DB_CLUB)
	end
	mailv = mailv or {}
	local mail_flag = false
	self.mail = mail.new(mailv)
	mail_flag = mail.init(self)
	if mail_flag == true then
		self:db_tagdirty(self.DB_MAIL)
	end
	info.attribute = attributes.new(self.base.race,self.base.level)
	info.attribute:add_attribute(self)
	self.battle_value = info.attribute:get_battle_value() + card_container.get_partner_battle(self)
    local now = shaco.now()//1000
    local now_day = now//86400
    local last_day = self.info.refresh_time//86400
    if now_day ~= last_day then
        self:onchangeday()
    end
end

function user:entergame()
	--[[self:send(IDUM_ENTERGAME, {info=self.info,open_time = config.open_server_time,battle_value = self.battle_value})
	scene.enter(self, self.info.last_city)
	if task.daily_update(self) == true then
		self:db_tagdirty(self.DB_ROLE)
    	self:db_tagdirty(self.DB_TASK)
    end]]
   local info = self.info
    self:send(IDUM_ENTERGAME, {info=self.info,open_time = config.open_server_time,battle_value = self.battle_value})
	self:send(IDUM_SYNCBATTLEVALUE, {battle_value=self.battle_value})
    itemop.refresh(self)
   if task.daily_update(self) == true then
		self:db_tagdirty(self.DB_ROLE)
    	self:db_tagdirty(self.DB_TASK)
    end
	self:send(IDUM_NOTICECLUBINFO, {info = self.club})
    self:send(IDUM_TASKLIST, {info = self.task.tasks})
    self.cards.refresh(self)
	self:send(IDUM_CARDPARTNERLIST,{partners = self.cards.__partner})
	self.cards.sync_partner_attribute(self)
    scene.enter(self, self.info.last_city)
end

function user:exitgame()
    scene.exit(self)
    self:db_flush(true)
end

function user:ontime(now)
	if self.info.physical_time > 0 then
		local __now = floor(now/1000)
		local difference_time = __now - self.info.physical_time
		local __physical,temp = math.modf(difference_time/tpgamedata.PhysicalTime)
		if __physical >= 1 then
			if self.info.physical + __physical >= tpgamedata.PhysicalMax then
				self.info.physical = tpgamedata.PhysicalMax
				self.info.physical_time = 0
				self:sync_role_data()
			else
				self.info.physical = self.info.physical + __physical
				self.info.physical_time = __now
				self:sync_role_data()
			end
		end
	else
		if self.info.physical == 0 then
			self.info.physical_time = floor(now/1000)
		end
	end
	local flag = false
    local now_day = floor((now/1000)/86400)
    local last_day = floor(self.info.refresh_time/86400)
    if now_day ~= last_day then
        self.across_day = 2
		flag = true
		ladder.onchangeday(self)
		
    end
	if flag == true then
		self.info.refresh_time = now//1000
	end
	if  self.across_day == 2 then
		if task.update_daily_task(self) then
			self.across_day = 1
		end
	end
	if self.across_day ~= 0 then
		club.update(self,false)
	end
end

function user:onchangeday()
	ladder.onchangeday(self)
	club.update(self,true)
	self.info.refresh_time = shaco.now()//1000
end

-- bag
function user:getbag(t)
    if t == BAG_EQUIP then
        return self.equip
    elseif t == BAG_MAT then
        return self.mat 
    else
        return self.package
    end
end

-- db
function user:db_tagdirty(t)
    self.db_dirty_flag = bor(self.db_dirty_flag, t)
end

function user:db_flush(force)
    local roleid = self.base.roleid
    local flag = self.db_dirty_flag
    local up_role = false
    if band(flag, self.DB_ROLE) ~= 0 then
        flag = band(flag, bnot(self.DB_ROLE))
        up_role = true
    elseif (force and (band(flag, self.DB_ROLE_DELAY) ~= 0)) then
        flag = band(flag, bnot(self.DB_ROLE_DELAY))
        up_role = true
    end
    if up_role then
        shaco.send(CTX.db, shaco.pack("S.role", {
            roleid=roleid,
            base=pb.encode("role_base", self.base),
            info=pb.encode("role_info", self.info),
       }))
    end
    if band(flag, self.DB_ITEM) ~= 0 then
            shaco.send(CTX.db, shaco.pack("S.ex", {
            name="item",
            roleid=roleid,
            data=pb.encode("item_list", {package=itemop.getall(self.package), 
                                         equip=itemop.getall(self.equip),
                                         mat=itemop.getall(self.mat)}),
        }))
        flag = band(flag, bnot(self.DB_ITEM))
		
    end   
    if band(flag, self.DB_TASK) ~= 0 then
        shaco.send(CTX.db, shaco.pack("S.ex", {
            name="task",
            roleid=roleid,
            data=pb.encode("task_list", {list = self.task.tasks}),
            }))
        flag = band(flag, bnot(self.DB_TASK))
    end
    if band(flag, self.DB_CARD) ~= 0 then	
    	local cards = card_container.get_card_container(self.cards.__card.__cards)
    	local container = {list = cards,partners = self.cards.__partner,own_cards = self.cards.__own_cards}
        shaco.send(CTX.db, shaco.pack("S.ex", {
            name="card",
            roleid=roleid,
            data=pb.encode("card_list", {list = container}),
            }))
        flag = band(flag, bnot(self.DB_CARD))
        card_container.set_equip(self)
    end
	if band(flag, self.DB_CLUB) ~= 0 then
		 shaco.send(CTX.db, shaco.pack("S.ex", {
            name="club_info",
            roleid=roleid,
            data=pb.encode("club_data", {data = self.club}),
            }))
        flag = band(flag, bnot(self.DB_CLUB))
	end
	if band(flag, self.DB_MAIL) ~= 0 then
		 shaco.send(CTX.db, shaco.pack("S.ex", {
            name="mail",
            roleid=roleid,
            data=pb.encode("mail_list", {data = self.mail.data,old_info = self.mail.old_info}),
            }))
        flag = band(flag, bnot(self.DB_MAIL))
	end
end

-- exp
function user:addexp(got)
    if got <= 0 then
        return
    end
    local base = self.base
    local info = self.info
    local index = base.race * 1000 + base.level
    info.exp = info.exp + got
    self:db_tagdirty(self.DB_ROLE)
	local flag = false
    while true do
        local tp = tprole[index]
        if tp then
            if info.exp >= tp.exp then 
                base.level = base.level+1
				
                index = index + 1
				task.set_task_progress(self,3,base.level,0)
				task.refresh_toclient(self, 3)
                info.exp = info.exp - tp.exp
                self:db_tagdirty(self.DB_ROLE)
				flag = true
            else
                break
            end
        else
            break
        end
    end
	if flag == true then
		self:level_log()
		self.info.attribute:compute_attribute(base.base,base.level)
		self.info.attribute:add_attribute(self)
		self:change_attribute(self)
		if base.level >= tpgamedata.dayTaskLevel then
			task.accept_daily_task(self)
		end
	end
end

function user:change_attribute(self)
	self.battle_value = self.info.attribute:get_battle_value() + card_container.get_partner_battle(self)
	self:sync_role_data()
	self:send(IDUM_UPDATEROLEATTRIBUTE,{attribute=self.info.attribute})	
end

-- coin
function user:coin_enough(take)
    return self.info.coin >= take
end

function user:coin_take(take)
    local old = self.info.coin
    if old >= take then
        self.info.coin = old - take
		self:money_log()
        return true
    else
        return false
    end
end

function user:coin_got(got)
    if got == 0 then
        return 0
    end
    local old = self.info.coin
    self.info.coin = old + got 
    if self.info.coin < 0 then
        self.info.coin = 0
    end
	self:money_log()
    return self.info.coin-old
end

-- gold
function user:gold_enough(take)
    return self.info.gold >= take
end

function user:gold_take(take)
    local old = self.info.gold
    if old >= take then
        self.info.gold = old - take
		self:money_log()
        return true
    else
        return false
    end
end

function user:gold_got(got)
    if got == 0 then
        return 0
    end
    local old = self.info.gold
    self.info.gold = old + got
    if self.info.gold < 0 then
        self.info.gold = 0     
    end
	self:money_log()
    return self.info.gold-old
end

-- send
function user:send(msgid, v)
    local name = MSG_RESNAME[msgid]
    assert(name)
    pb.encode(name, v, function(buffer, len)
        local msg, sz = shaco.pack(IDUM_GATE, self.connid, msgid, buffer, len)
        shaco.send(CTX.gate, msg, sz)
    end)
end

function user:senderr(err)
    self:send(self.connid, IDUM_ERROR, {err=err})
end

-- chan
function user:chan_subscribe(chanid)
    shaco.send(CTX.gate, shaco.pack(IDUM_SUBSCRIBE, self.connid, chanid))
end

function user:chan_unsubscribe(chanid)
    shaco.send(CTX.gate, shaco.pack(IDUM_UNSUBSCRIBE, self.connid, chanid))
end

function user:chan_publish(chanid, msgid, v)
    local name = MSG_RESNAME[msgid]
    if name == nil then
        error("msg res msgid nil", 2)
    end
    pb.encode(name, v, function(buffer, len)
        local msg, sz = shaco.pack(IDUM_PUBLISH, self.connid, chanid, msgid, buffer, len)
        shaco.send(CTX.gate, msg, sz)
    end)
end

function user:sync_role_data()
	local data = sync_role_gen()
	data.coin=self.info.coin
    data.gold=self.info.gold
	data.exp=self.info.exp
   	data.level=self.base.level
	data.physical = self.info.physical
	data.battle = self.battle_value
	self:send(IDUM_SYNCROLEDATA,{info=data})
end

function user:save_drop_item()
	for i = 1,#self.item_drop do
		itemop.gain(self,self.item_drop[i].itemid , self.item_drop[i].cnt)
	end
	itemop.refresh(self)
end

function user:set_level(level)
	self.base.level = level
	self.info.attribute:compute_attribute(self.base.race,level)
	self.info.attribute:add_attribute(self)
	self:change_attribute(self)
	self:db_tagdirty(self.DB_ROLE)
	if level >= 20 then
		task.accept_daily_task(self)
	end
end

function user:compute_battle_value()
	self.battle_value = self.info.attribute:get_battle_value() + card_container.get_partner_battle(self)
	task.set_task_progress(self,25,self.battle_value,0)
	task.refresh_toclient(self, 25)
	self:send(IDUM_SYNCBATTLEVALUE, {battle_value=self.battle_value})
end

function user:money_log()
	local roleid = self.base.roleid
	local coin = self.info.coin
	local gold = self.info.gold
	local log_name =os.date("x_log_money_%Y%m%d", shaco.now()//1000)
	local create_time = os.date("%Y-%m-%d %X", shaco.now()//1000)
	shaco.send(CTX.logdb, shaco.pack("S.insert",{name = log_name,index = 1,fields = {roleid = roleid,coin = coin,gold = gold,create_time = create_time}}))
end

function user:level_log()
	local roleid = self.base.roleid
	local level = self.base.level
	local log_name =os.date("x_log_level_%Y%m%d", shaco.now()//1000)
	local create_time = os.date("%Y-%m-%d %X", shaco.now()//1000)
	shaco.send(CTX.logdb, shaco.pack("S.insert",{name = log_name,index = 2,fields = {roleid = roleid,level = level,create_time = create_time}}))
end

function user:create_log(roleid)
	local create_time = os.date("%Y-%m-%d %X", shaco.now()//1000)
	local log_name =os.date("x_log_create_%Y%m%d", shaco.now()//1000)
	shaco.send(CTX.logdb, shaco.pack("S.insert",{name = log_name,index = 3,fields = {roleid = roleid,create_time = create_time}}))
end

function user:card_log(__type,PriceType,cardv)
	local roleid = self.base.roleid
	local buy_type = ""
	if __type == BUY_SINGLE then --coin buy
		if PriceType == 0 then
			buy_type = "single_coin"
		elseif PriceType == 1 then --single gold buy 
			buy_type = "single_gold"
		end
	elseif __type == BUY_TEN then -- ten
		buy_type = "ten_gold"
	end
	local tb = {}
	local cards = ""
	for i =1,#cardv do
		table.insert(tb,string.format("%s",cardv[i]))
		cards =table.concat(tb,",")
	end
	local create_time = os.date("%Y-%m-%d %X", shaco.now()//1000)
	local log_name =os.date("x_log_card_%Y%m%d", shaco.now()//1000)
	shaco.send(CTX.logdb, shaco.pack("S.insert",{name = log_name,index = 4,fields = {roleid = roleid,buy_type = buy_type,cards = cards,create_time = create_time}}))
end

function user:item_log(itemid,itemcnt)
	local roleid = self.base.roleid
	local log_name =os.date("x_log_item_%Y%m%d", shaco.now()//1000)
	local create_time = os.date("%Y-%m-%d %X", shaco.now()//1000)
	shaco.send(CTX.logdb, shaco.pack("S.insert",{name = log_name,index = 5,fields = {itemid = itemid,roleid = roleid,itemcnt = itemcnt,create_time = create_time}}))
end

function user:log_in_out_log(in_out)
    shaco.error("log login 1")
	if not self.base then
		return
	end
	local roleid = self.base.roleid
	local cur_time = os.date("%Y-%m-%d %X", shaco.now()//1000)
	local login_time = ""
	local logout_time = ""
	if in_out == 1 then  ---login
		login_time = cur_time
	else
		logout_time = cur_time
	end
	local log_name =os.date("x_log_in_out_%Y%m%d", shaco.now()//1000)
    shaco.error("log login")
	shaco.send(CTX.logdb, shaco.pack("S.insert",{name = log_name,index = 6,fields = {login_time = login_time,roleid = roleid,logout_time = logout_time}}))
end

function user:get_max_atrribute()
	local verify_value = 0
	local battle_value = self.info.attribute:get_battle_value()
	local partner_pos,partner_battle = card_container.get_max_partner_battle(self)
	if partner_battle > battle_value then
		verify_value = self.cards.__card.__attributes[partner_pos]:compute_verify()
	else
		verify_value = self.info.attribute:compute_verify()
	end
	return verify_value
end

function user:x_log_role_cheat(ectypeid,clubid,robotid,opponent_battle)
	if not self.base then
		return
	end
	local roleid = self.base.roleid
	local cur_time = os.date("%Y-%m-%d %X", shaco.now()//1000)
	local log_name =os.date("x_log_role_cheat_%Y%m%d", shaco.now()//1000)
	local battle_value = self.info.attribute:get_battle_value()
	local verify_value = self.info.attribute:compute_verify()
	local bag = self:getbag(BAG_EQUIP)
	local role_weapon = ""
	local partners = self.cards.__partner
	local card__attributes = self.cards.__card.__attributes
	local pos_level_breakthrough_guarantee = ""
	for i =1,2 do
		if partners[i].pos > 0 then
			local card = card_container.get_target(self, partners[i].pos)
			if not card then
				shaco.trace(sfmt("partner info error pos ==  %d !!! ", partners[i].pos))
				break
			end
			local card_battle_value = card__attributes[partners[i].pos]:compute_battle()
			pos_level_breakthrough_guarantee = pos_level_breakthrough_guarantee.."pos="..partners[i].pos..",id="..card.cardid..",lvl="..card.level..",breakth="..card.break_through_num..",battle="..card_battle_value..";"
		end
	end
	local fields = {}
	fields.roleid = roleid ; fields.ectypeid = ectypeid;fields.battle_value = battle_value;fields.pos_level_breakthrough_guarantee = pos_level_breakthrough_guarantee
	fields.clubid = clubid ; fields.opponent_battle = opponent_battle; fields.robot_id = robotid; fields.cur__time = cur_time
	shaco.send(CTX.logdb, shaco.pack("S.insert",{name = log_name,index = 7,fields = fields}))
end

function user:weapon_intensify(rate,tp)
	self.info.attribute:weapon_intensify(rate,tp)
end

function user:change_role_battle_value()
	self.battle_value = self.info.attribute:get_battle_value() + card_container.get_partner_battle(self)
	self:sync_role_data()
end

return user
