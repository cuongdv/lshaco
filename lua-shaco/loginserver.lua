local mworker = require "mworker"
local shaco = require "shaco"
local socket = require "socket"
local crypt = require "crypt.c"

local auth_handler
local login_handler

local function worker_handler(id)
    shaco.trace(sformat('Client %d comein', id))
    socket.readon(id)

    local challenge = randomkey()
    assert(socket.send(id, crypt.base64encode(challenge)..'\n'))

    local client_key = crypt.base64decode(assert(socket.read(id, '\n')))
    if #client_key ~= 8 then
        error('Invalid client key')
    end

    local server_key = randomkey()
    assert(socket.send(id, crypt.base64encode(crypt.dhexchange(server_key))..'\n'))

    local secret = crypt.dhsecret(client_key, server_key)

    local response = assert(socket.read(id, '\n'))
    if crypt.hmac64(challenge, secret) ~= crypt.base64decode(response) then
        socket.send(id, '400 Bad Request\n')
        error('Challenge failed')
    end

    local token = crypt.base64decode(assert(socket.read(id, '\n')))
    token = crypt.desdecode(secret, token)

    local ok, uid, server = pcall(auth_handler, id, token)
    return ok, uid, server, secret
end

local function master_handler(id, worker, ok, uid, server, secret)
    if not ok then
        socket.send(id, '401 Unauthorized\n')
        error('Auth failed')
    end
    socket.start(id)
    socket.readon(id)
   
    local ok, err = pcall(login_handler, id, uid, server, secret)
    if ok then
        socket.send(id, '200 '..crypt.base64encode(err or "")..'\n')
    else
        socket.send(id, '403 Forbidden\n')
        error(err)
    end
end

local function master_init(conf)
    --local handle = shaco.uniqueservice('slave')
end

local function worker_init(conf)
    login_handler = nil
end

local function loginserver(conf)
    auth_handler  = assert(conf.auth_handler)
    login_handler = assert(conf.login_handler)
    conf.master_init = master_init
    conf.worker_init = worker_init
    conf.master_handler = master_handler
    conf.worker_handler = worker_handler
    mworker(conf)
end

return loginserver
