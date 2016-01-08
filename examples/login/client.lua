local shaco = require 'shaco'
local socket = require "socket"
local crypt = require "crypt.c"

shaco.start(function()
    local login_addr = '127.0.0.1:8000'
    local id = assert(socket.connect(login_addr))
    socket.readon(id)

    local challenge = assert(socket.read(id, '\n'))
    challenge = crypt.base64decode(challenge)

    local client_key = crypt.randomkey()
    assert(socket.send(id, crypt.base64encode(dhexchange(client_key))..'\n'))

    local server_key = assert(socket.read(id, '\n'))
    server_key = crypt.base64decode(server_key)
    local secret = crypt.dhsecret(server_key, client_key)

    print ('secret: ', crypt.hexencode(secret))
end)
