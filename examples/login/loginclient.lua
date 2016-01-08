local shaco = require 'shaco'
local socket = require "socket"
local crypt = require "crypt.c"
local randomkey = crypt.randomkey
local base64encode = crypt.base64encode
local base64decode = crypt.base64decode
local dhexchange = crypt.dhexchange
local dhsecret = crypt.dhsecret
local hmac64 = crypt.hmac64
local hashkey = crypt.hashkey
local desdecode = crypt.desdecode
local desencode = crypt.desencode
local hexencode = crypt.hexencode
local sformat = string.format
local spack = string.pack
local sunpack = string.unpack

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

    local result = assert(socket.read(id, '\n'))
    print ('result: ', result)
    assert(string.sub(result, 1, 4) == '200 ')
    local subid = tonumber(base64decode(string.sub(result, 5)))
    print ('subid: ', subid)
    socket.close(id)

    local gate_addr = '127.0.0.1:8001'
    local id = assert(socket.connect(gate_addr))
    print ('connect gate ok')

    local function sendpackage(id, data)
        assert(socket.send(id, spack('>s2', data)))
    end
   
    local function readpackage(id)
        local head = assert(socket.read(id, 2))
        head = sunpack('>I2', head)
        return assert(socket.read(id, head))
    end

    local function sendrequest(id, data, session)
        data = spack('>I4', session)..data
        assert(socket.send(id, spack('>s2', data)))
    end
    
    local function readresponse(id)
        local head = assert(socket.read(id, 2))
        head = sunpack('>I2', head)
        local data = assert(socket.read(id, head))
        local session, ok, pos = sunpack('>I4B', data)
        if ok == 1 then
            return string.sub(data, pos)
        else
            shaco.error('request failed')
            return nil
        end
    end

    socket.readon(id)

    local version = 0 -- version
    local handshake = sformat('%s@%s#%s:%s', 
    base64encode(uid),
    base64encode(server),
    base64encode(subid),
    version)

    local hmac = hmac64(hashkey(handshake), secret)
    local handshake = sformat('%s:%s', handshake, base64encode(hmac))
    print ('send handshake:', handshake)
    sendpackage(id, handshake)

    local result = readpackage(id)
    print ('handshake result: ', result)
    assert(result == '200 OK')
 
    sendrequest(id, 'msg0', 0)
    print('=====>', readresponse(id))
    
    sendrequest(id, 'msg1', 1)
    --print('=====>', readresponse(id))

    socket.close(id)


    local gate_addr = '127.0.0.1:8001'
    local id = assert(socket.connect(gate_addr))
    print ('connect gate ok')

    socket.readon(id)

    version = version + 1
    local handshake = sformat('%s@%s#%s:%s', 
    base64encode(uid),
    base64encode(server),
    base64encode(subid),
    version)

    local hmac = hmac64(hashkey(handshake), secret)
    local handshake = sformat('%s:%s', handshake, base64encode(hmac))
    print ('send handshake:', handshake)
    sendpackage(id, handshake)

    local result = readpackage(id)
    print ('handshake result: ', result)
    assert(result == '200 OK')
 
    --sendrequest(id, 'msg0', 0)
    --print('=====>', readresponse(id))
    
    sendrequest(id, 'msg1', 1)
    print('=====>', readresponse(id))

    sendrequest(id, 'msg2', 2)
    print('=====>', readresponse(id))

end)
