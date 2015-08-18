local shaco = require "shaco"
local pb = require "protobuf"
local tbl = require "tbl"
local CMD = require "cmd"
local cmdcall = require "cmdcall"
local sfmt = string.format
local sgsub = string.gsub
local REQ = require "req"
local CTX = require "ctx"
local tpfix = require "tpfix"
local sgmatch = string.gmatch
local tinsert = table.insert
local tconcat = table.concat
local rcall = shaco.call

require "msg_error"
require "msg_client"
require "msg_server"
require "struct"
require "enum"

local userpool = require "userpool"
local ectype_fast = require "ectype_fast"
local itemop = require "itemop"
local config = require "config"
local ladder = require "ladder"
local mail_fast = require "mail_fast"
local task_fast = require "task_fast"

REQ.__REG {
    "h_scene",
    "h_login",
    "h_item",
    "h_gm",
    "h_task",
    "h_equip",
    "h_ectype",
    "h_skill",
    "h_card",
    "h_shop",
	"h_dazzle",
	"h_mystery",
	"h_club",
	"h_ladder",
	"h_mail",
	"h_function"
}

local MSG_REQNAME = require "msg_reqname"
--extra REQ, add by hand
MSG_REQNAME[IDUM_NETDISCONN] = "UM_NETDISCONN"

local function init_pb()
    local path = "../res/pb"
    local files = {
        "enum",
        "struct",
        "msg_client",
        "msg_server",
    }
    for _, v in ipairs(files) do
        pb.register_file(sfmt("%s/%s.pb", path, v))
    end
end

local lastb = 0

shaco.start(function()
	--shaco.send(CTX.db, shaco.pack("S.create", {}))
    shaco.timeout(1000, function()
        local now = shaco.now()
        userpool.foreach(now)
		ladder.update(now)
		mail_fast.update(now)
		task_fast.update(now)
        --local k, b = collectgarbage "count"
        --b = k*1024
        --shaco.trace(tonumber(k) .. "----"..tonumber(b - lastb))
        --lastb = b
    end)

    shaco.register_command(CMD)

    shaco.dispatch("um", function(_,_, msgid, connid, subid, msg, sz)
        if msgid == IDUM_GATE then
            assert(connid)
            assert(subid)
            local h = REQ[subid]
            if h then
                shaco.trace(sfmt("Client %d recv msg %d", connid, subid))
                local v = pb.decode(MSG_REQNAME[subid], msg, sz)
                if subid ~= IDUM_LOGIN then
                    local ur = userpool.find_byconnid(connid)
                    if ur then -- check ur ?
                        local r = h(ur, v)
                        if not r then
                            r = SERR_OK
                        end
                        ur:send(IDUM_RESPONSE, {msgid=subid, err=r})
                        if userpool.isgaming(ur) then
                            ur:db_flush()
                        end
                    end
                else
                    h(connid, v) 
                end
            else
                shaco.warning(sfmt("Client %d recv invalid msgid %d", connid, subid))
            end
        end
    end)

    shaco.publish("game")
    CTX.gate = shaco.subscribe("gate")
    CTX.logdb = shaco.subscribe("dblog", true)
    CTX.db = shaco.uniquemodule("db", true, 
    function(type, vhandle)
        shaco.fork(function()
            print "db load ok"
            --local info = rcall(vhandle, "L.role", 1000)
            --if info then
                --info = pb.decode("role_info", info)
                --tbl.print(info, "info")
            --end 
        end)
    end,
    function(type)
    end)

    config.init()  
    tpfix.init()
    init_pb()
   
    ectype_fast.init()
    itemop.init()
	mail_fast.init()
	task_fast.init()
end)
