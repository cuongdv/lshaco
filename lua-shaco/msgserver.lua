local gateserver = require "gateserver"
local crypt = require "crypt.c"
local spack = string.pack
local sunpack = string.unpack
local sformat = string.format
local ssub = string.sub
local base64encode = crypt.base64encode
local base64decode = crypt.base64decode

local msgserver = {}

local servername
local user_online = {}

function msgserver.user_name(uid, subid)
    return sformat('%s@%s#%s', 
        base64encode(uid),
        base64encode(servername),
        base64encode(subid))
end

function msgserver.login(name)
    user_online[name] = {
        sock = false,
        addr = false,
        name = name, 
        version = 0,
        index = 0,
    }
end

function msgserver.logout(name)
    user_online[name] = nil
end

function msgserver.start(handler)
    local handler_open = assert(handler.open) -- (servername, conf)
    local handler_disconnect = assert(handler.disconnect)
    local handler_message = assert(handler.message)

    local handshake = {}
    local connection = {}
    local expire_number

    local server = {}

    function server.open(name, conf)
        servername = assert(name)
        expire_number = assert(conf.expire_number)
        handler_open(servername, conf)
    end

    function server.connect(id, addr)
        gateserver.openclient(id)
        handshake[id] = '127.0.0.1' -- todo: get addr
    end

    function server.disconnect(id, err)
        if handshake[id] then
            handshake[id] = nil
        end
        local u = connection[id]
        if u then
            connection[id] = nil
            handler_disconnect(u.name, err)
        end
    end

    local function sendpackage(id, data)
        gateserver.send(id, spack('>s2', data))
    end

    local function do_auth(id, addr, data)
        local username, version, hmac = string.match(data, '([^@]+)@([^#]+)#(.+)')
        local u = user_online[username]
        if u == nil then
            return '404 Not Found'
        end
        if version <= u.version then
            return '403 Forbidden'
        end
        hmac = crypt.base64decode(hmac)
        local key = username..':'..version
        key = crypt.hmac64(crypt.hashkey(key))
        if token ~= hmac then
            return '401 Unauthorized'
        end 

        u.sock = id
        u.addr = addr
        u.version = u.version + 1
        connection[id] = u
    end

    local function auth(id, addr, data)
        local ok, result = pcall(do_auth, id, addr, data)
        if not ok then
            shaco.error(result)
            result = '400 Bad Request'
        end
        local succeed
        if result == nil then
            result = '200 OK'
            succeed = true
        end
        sendpackage(id, data)
        if not succeed then
            gateserver.closeclient(id)
        end
    end

    local function expire_response(u)
        if u.index >= expire_number*2 then
            local max = -1
            local response = u.response
            for k, v in pairs(response) do
                if v[2] then
                    local diff = v[4] - expire_number
                    if diff < 0 then
                        response[k] = nil
                    else
                        v[4] = diff
                        if max < diff then
                            max = diff
                        end
                    end
                end
            end
            max = max+1
        end
    end

    local function do_request(id, data)
        local u = assert(connection[id])
        assert(data >= 4)
        local session, pos = sunpack('>I4', data)
        local data = ssub(data, pos)

        local p
        if session > u.session then
            error('Session is ahead')
        elseif session < u.session then -- must be another connection
            p = u.response[session] 
            if not p then
                error('Session no cached')
            end
            if p.version == u.version then
                error('Session is expired')
            end
        end
        if p == nil then
            p = {id}
            u.response[session] = p
            u.session = session + 1
            local ok, result = pcall(handler_message(u.name, data))
            if not ok then
                shaco.error(result)
                result = spack('>I4', session)..'\0'
            else
                result = spack('>I4', session)..'\1'..result
            end
            p[2] = result
            p[3] = u.version
            p[4] = u.index
            if connection[id] then
                sendpackage(id, result)
            end
        else
            p[1] = id
            if p[2] == nil then
                return -- handling
            end
            p[3] = u.version
            p[4] = u.index
            sendpackage(id, p[2])
        end
        u.index = u.index + 1
        expire_response(u)
    end

    local function request(id, data)
        local ok, err = pcall(do_request, id, data)
        if not ok then
            shaco.error(err)
            if connection[id] then
                gateserver.closeclient(id)
            end
        end
    end

    function server.message(id, data)
        local addr = handshake[id]
        if addr then
            auth(id, addr, data)
            handshake[id] = nil
        else
            request(id, data)
        end
    end

    gateserver.start(server)

end
