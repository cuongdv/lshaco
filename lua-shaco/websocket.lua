local http = require "http"
local socket = require "socket"
local crypt = require "crypt.c"
local tbl = require "tbl"

local websocket = {}

local function accept(code, method, uri, head_t, body, version)
    if method ~= "GET" then
        return 405
    end
    if version < 1.1 then
        return 505
    end
    local upgrade = head_t["upgrade"]
    if not upgrade or upgrade:lower() ~= "websocket" then
        return 412--X
    end
    local connection = head_t["connection"]
    if not connection or connection:lower() ~= "upgrade" then
        return 412--X
    end
    local key = head_t["sec-websocket-key"]
    if not key then
        return 412--X
    end
    local ws_version = head_t["sec-websocket-version"]
    if ws_version ~= "13" then
        return 426
    end
    return 101,key,uri
end

local function accept_response(id, code, key, uri)
    local head_t = {}
    if code == 101 then
        head_t["upgrade"] = "websocket"
        head_t["connection"] = "upgrade"
        head_t["sec-websocket-accept"] = crypt.base64encode(
            crypt.sha1(key.."258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))
    end
    http.response(id,code, nil, head_t) 
end

function websocket.handshake(id, code, method, uri, head_t, body, version)
    accept_response(id, accept(code, method, uri, head_t, body, version))
end

function websocket.connect(host, uri, headers)
    local port
    host, port = host:match("([^:]+):?(%d*)$")
    port = tonumber(port) or 80
    local id = assert(socket.connect(host, port))
    local headers = headers or {}
    headers['host'] = host
    headers['upgrade'] = 'websocket'
    headers['connection'] = 'upgrade'
    headers['sec-websocket-key'] = 'test-websocket-key'
    headers['sec-websocket-version'] = '13'
    local code = http.get(id, uri, headers) -- skip check header ?
    if code == 101 then
        return id
    else
        socket.close(id)
        return nil, code
    end
end

local function encode(data, len, maskkey)
    print ("decode all:", data, len, maskkey)
    local i=-1
    return string.gsub(data, ".", function(c)
        i=i+1
        print ("decode i:", i, c)
        return string.char(string.byte(c) ~ string.byte(maskkey, i%4+1))
    end)
end
local decode = encode

local function read_frame(id)
    local data = assert(socket.read(id,2))
    local B1, B2 = string.unpack("BB", data)
    local fin = (B1>>7)&1
    local opcode = B1&0xf
    local mask = (B2>>7)&1
    local len = B2&0x7f
    if opcode==0x8 or opcode==0x9 or opcode==0xa then
        assert(fin==1 and len<126, opcode)
    end
    if len < 126 then
    elseif len == 126 then
        len = assert(socket.read(id,2))
        len = string.unpack(">I2", len)
    else
        assert(len==127, len)
        len = assert(socket.read(id,8))
        len = string.unpack(">I8", len)
    end
    local maskkey
    if mask==1 then
        maskkey = assert(socket.read(id,4))
    end
    local data = assert(socket.read(id, len))
    if maskkey then
        data = decode(data, len, maskkey)
    end
    print (opcode, data, #data, fin)
    return opcode, data, fin
end

function websocket.read(id)
    local result, opcode, data, fin
    opcode, result, fin = read_frame(id)
    if opcode == 0x8 then
        websocket.close(id)
        return nil, "close"
    elseif opcode == 0x9 then
        websocket.pong(id, result)
        return result, "ping"
    elseif opcode == 0xa then
        return result, "pong"
    end
    while fin ~= 1 do
        opcode, data, fin = read_frame(id)
        result = result .. data
    end
    return result, "data"
end

local function send_frame(id, head, data, maskkey)
    local len, s
    if data then
        len = #data
        if maskkey then
            data = encode(data, len, maskkey)
        end
    else
        len = 0
    end
    local maskbit = maskkey and 1 or 0
    if len < 126 then
        s = string.pack(">BB", head,len|(maskbit<<7))
    elseif len < 65536 then
        s = string.pack(">BBI2",head,126|(maskbit<<7),len)
    else
        assert(len<=(2^64)-1)
        s = string.pack(">BBI4",head,127|(maskbit<<7),len)
    end
    if data then
        s = s..data
    end
    assert(socket.send(id, s))
end

function websocket.ping(id, data, maskkey)
    send_frame(id, 0x89)
end

function websocket.pong(id, data, maskkey)
    send_frame(id, 0x8a)
end

function websocket.close(id, code, reason, maskkey)
    local data
    if code then
        data = string.pack(">H", code)
        if reason then
            data = data..reason
        end
    end
    send_frame(id, 0x88, data, maskkey)
    socket.close(id, false) -- just not force close
end

function websocket.send(id, data, maskkey)
    send_frame(id, 0x82, data, maskkey)
end

function websocket.text(id, data, maskey)
    send_frame(id, 0x81, data, maskkey)
end

return websocket
