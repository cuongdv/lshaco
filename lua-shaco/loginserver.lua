local mworker = require "mworker"
local shaco = require "shaco"
local socket = require "socket"
local crypt = require "crypt.c"
local randomkey = crypt.randomkey
local base64encode = crypt.base64encode
local base64decode = crypt.base64decode
local dhexchange = crypt.dhexchange
local dhsecret = crypt.dhsecret
local hmac64 = crypt.hmac64
local desdecode = crypt.desdecode
local sformat = string.format

local handler_auth
local handler_login
local handler_command
local handler_master_init
local handler_worker_init

local function worker_handler(id)
    shaco.trace(sformat('Client %d comein', id))
    socket.readon(id)

    local challenge = randomkey()
    assert(socket.send(id, base64encode(challenge)..'\n'))

    local client_key = base64decode(assert(socket.read(id, '\n')))
    if #client_key ~= 8 then
        error('Invalid client key')
    end

    local server_key = randomkey()
    assert(socket.send(id, base64encode(dhexchange(server_key))..'\n'))

    local secret = dhsecret(client_key, server_key)

    local response = assert(socket.read(id, '\n'))
    if hmac64(challenge, secret) ~= base64decode(response) then
        socket.send(id, '400 Bad Request\n')
        error('Challenge failed')
    end
    
    local token = base64decode(assert(socket.read(id, '\n')))
    token = desdecode(secret, token)

    local ok, uid, server = pcall(handler_auth, token)
    return ok, uid, server, secret
end

local function master_handler(id, worker, ok, uid, server, secret)
    socket.start(id)
    if not ok then
        if uid ~= nil then
            socket.send(id, '401 Unauthorized\n') -- error in handler_auth
            error(uid)
        else
            error('Auth failed')
        end
    end
    local ok, err = pcall(handler_login, uid, server, secret)
    if ok then
        socket.send(id, '200 '..base64encode(err or "")..'\n')
    else
        socket.send(id, '403 Forbidden\n')
        error(err)
    end
end

local function master_init()
    --local handle = shaco.uniqueservice('slave')
    shaco.dispatch('lua', function(source, session, cmd, ...)
        local f = CMD[cmd]
        if t then
            shaco.ret(shaco.pack(f(...)))
        else
            shaco.ret(shaco.pack(handler_command(cmd, ...)))
        end
    end)
    if handler_master_init then
        handler_master_init()
    end
end

local function worker_init()
    handler_login = nil
    handler_command = nil
    shaco.dispatch('lua')
    if handler_worker_init then
        handler_worker_init()
    end
end

local function loginserver(conf)
    handler_auth = assert(conf.auth) -- (token)
    handler_login = assert(conf.login) -- (uid, server, secret)
    handler_command = assert(conf.command) -- (cmd, ...)
    handler_master_init = conf.master_init
    handler_worker_init = conf.worker_init
    conf.master_init = master_init
    conf.worker_init = worker_init
    conf.master_handler = master_handler
    conf.worker_handler = worker_handler
    mworker(conf)
end

return loginserver
