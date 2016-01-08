local shaco = require "shaco"
local msgserver = require "msgserver"

local loginserver = tonumber(...)

local server = {}
local username_map = {}
local users = {}

function server.login(uid, subid)
    local username = msgserver.user_name(uid, subid)
    shaco.trace(sformat('User %s login', username))

    -- monitor this
    shaco.sleep(1000)
    local u = {
        username = username,
    }
    users[uid] = u
    username_map[username] = u
    msgserver.login(username)
end

local function logout(u)
    local username = msgserver.user_name(uid, subid)
    assert(u.name == username)
    msgserver.logout(username)
    users[uid] = nil
    username_map[username] = nil
    shaco.call(loginserver, 'logout', uid, u.subid)
end

function server.logout(uid)
    local u = users[uid]    
    if u then
        logout(u)
    end
end

function server.kick(username)
    local u = username_map[username]
    if u then
        logout(u)
    end
end

function server.disconnect(username, err)
    shaco.trace(sformat('User %s disconnect %s', username, err))
end

function server.message(username, data)
    shaco.trace(sformat('User %s message %s', username, data))
end

function server.open(servername, conf)
    shaco.call(loginserver, 'lua', 'register_gate', servername, shaco.handle())
end
