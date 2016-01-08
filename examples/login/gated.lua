local shaco = require "shaco"
local msgserver = require "msgserver"
local sformat = string.format

local loginserver = tonumber(...)

local server = {}

local username_map = {}
local users = {}
local internal_id = 0

function server.login(uid, secret)
    -- monitor this
    shaco.sleep(1000)

    internal_id = internal_id + 1
    local subid = internal_id
    local username = msgserver.user_name(uid, subid)
    shaco.trace(sformat('User %s login', username))

    local u = {
        name = username,
        uid = uid,
        subid = subid,
    }
    users[uid] = u
    username_map[username] = u
    msgserver.login(username)

    return subid
end

-- call by client
function server.logout(uid)
    local u = users[uid]    
    if u then
        local username = u.name
        msgserver.logout(username)
        users[uid] = nil
        username_map[username] = nil
        shaco.call(loginserver, 'lua', 'logout', uid, u.subid)
    end
end

-- call by loginserver
function server.kick(uid, subid)
    local u = users[uid]
    if u then
        local username = msgserver.user_name(uid, subid)
        assert(u.name == username)
        shaco.call(shaco.handle(), 'lua', 'logout', uid)
    end
end

function server.disconnect(username, err)
    shaco.trace(sformat('User %s disconnect %s', username, err))
end

function server.message(username, data)
    shaco.trace(sformat('User %s message %s', username, data))
end

function server.open(servername, conf)
    local slaveid = tonumber(shaco.getenv('slaveid')) or 0
    local handle = slaveid<<8 | shaco.handle()
    shaco.call(loginserver, 'lua', 'register_gate', servername, handle)
end

msgserver.start(server)
