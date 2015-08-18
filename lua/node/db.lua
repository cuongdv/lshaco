local shaco = require "shaco"
local sfmt = string.format
local mysql = require "mysql"
local REQ = require "req"
local snapshot = require "snapshot"
REQ.__REG {
    "h_game"
}

local conn

local function fini_db()
    conn:close()
end

local function ping()
    while true do
        conn:ping()
        --shaco.info("ping")
        shaco.sleep(1800*1000)
    end
end

shaco.start(function()
    shaco.publish("db")
    shaco.subscribe("game")
    
    conn = assert(mysql.connect{
        host = shaco.getstr("gamedb_host"), 
        port = shaco.getstr("gamedb_port"),
        db = shaco.getstr("gamedb_name"), 
        user = shaco.getstr("gamedb_user"), 
        passwd = shaco.getstr("gamedb_passwd"),
    })

    shaco.dispatch("um", function(session, source, name, v)
        local h = REQ[name]
        if h then
            h(conn, source, session, v)
        else
            shaco.warning(sfmt("db recv invalid msg %s", name))
        end
    end)

    shaco.fork(ping)
end)
