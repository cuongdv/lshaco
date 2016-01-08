local shaco = require 'shaco'
local socket = require "socket"
local crypt = require "crypt.c"
local randomkey = crypt.randomkey
local base64encode = crypt.base64encode
local base64decode = crypt.base64decode
local dhexchange = crypt.dhexchange
local dhsecret = crypt.dhsecret
local hmac64 = crypt.hmac64
local desdecode = crypt.desdecode
local desencode = crypt.desencode
local hexencode = crypt.hexencode
local sformat = string.format

shaco.start(function()
    local login_addr = '127.0.0.1:8000'
    local id = assert(socket.connect(login_addr))
    socket.readon(id)

    local challenge = assert(socket.read(id, '\n'))
    challenge = base64decode(challenge)

    local client_key = randomkey()
    assert(socket.send(id, base64encode(dhexchange(client_key))..'\n'))

    local server_key = assert(socket.read(id, '\n'))
    server_key = base64decode(server_key)
    local secret = dhsecret(server_key, client_key)

    print ('secret: ', hexencode(secret))
   
    challenge = base64encode(hmac64(challenge, secret))--'12347890'))
    assert(socket.send(id, challenge..'\n'))

    local uid = 'uid001'
    local server = 'gate1'
    local pass = 'password'

    local token = sformat('%s@%s#%s', 
    base64encode(uid),
    base64encode(server),
    base64encode(pass))
    token = desencode(secret, token)
    token = base64encode(token)
    assert(socket.send(id, token..'\n'))

    while true do
        print(assert(socket.read(id, '\n')))
    end
end)
