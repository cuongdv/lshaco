local shaco = require "shaco"
local loginserver = require "loginserver"
local crypt = require "crypt.c"
local base64encode = crypt.base64encode
local base64decode = crypt.base64decode
local hexencode = crypt.hexencode
local sformat = string.format

local server = {
    address = '127.0.0.1:8000',
    worker = 20,
}

local user_online = {}
local server_list = {}

function server.auth(token)
    local uid, server, pass = string.match(token, '([^@]+)@([^#]+)#(.+)')
    uid = base64decode(uid)
    server = base64decode(server)
    pass = base64decode(pass)
    assert(pass == 'password')
    return uid, server
end

function server.login(uid, server, secret)
    shaco.trace(sformat('User %s@%s login, secret is %s', uid, server, hexencode(secret)))
    local gate = server_list[server]
    if not gate then
        error(sformat('Server %s is no found', server))
    end
    local u = user_online[uid]    
    if u then
        shaco.call(gate, 'lua', 'kick', uid, u.subid)
    end
    if user_online[uid] then
        assert(sformat('User %s already login in %s', uid, server))
    end
    local subid = shaco.call(gate, 'lua', 'login', uid, secret)
    user_online[uid] = {
        server = server,
        subid = subid,
    }
    return subid
end

local CMD = {}

function CMD.register_gate(server, handle)
    shaco.info(sformat('Server register [%02x] %s', handle, server))
    server_list[server] = handle
end

function CMD.logout(uid, subid)
    local u = user_online[uid]
    if u then
        shaco.trace(sformat('%s@%s is logout', uid, u.server))
        user_online[uid] = nil
    end
end

function server.command(cmd, ...)
    local f = CMD[cmd]
    return f(...)
end

function server.worker_init()
    -- todo
    shaco.kill('slave')
end

loginserver(server)
