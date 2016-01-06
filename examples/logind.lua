local loginserver = require "loginserver"
local crypt = require "crypt.c"

local server = {
    address = '127.0.0.1:1234',
    worker = 4,
}

function server.auth_handler(id, token)
    -- base64encode(uid)@base64encode(server):base64encode(password)
    local uid, server, pass = string.match('(%w+)@(%w+):(%w+)', token)
    uid = crypt.base64decode(uid)
    server = crypt.base64decode(server)
    pass = crypt.base64decode(pass)
    return server, uid
end

function server.login_handler(id, uid, server, secret)
end

local CMD = {}

function server.command_handler(cmd, ...)
    local f = CMD[cmd]
    shaco.ret(shaco.pack(f(...)))
end

loginserver(server)
