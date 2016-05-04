local socketchannel = require "socketchannel"
local tconcat = table.concat
local sbyte = string.byte
local ssub = string.sub
local sformat = string.format
local assert = assert
local tonumber = tonumber
local tostring = tostring
local ipairs = ipairs

local redis = {}

local __M = {}
local __meta = {
    __index = __M,
}

local __response_type = {}

local function compose_command(cmd, ...)
    local arg = {...}
    local t = {'*'..#arg+1, '$'..#cmd, cmd}
    for _, v in ipairs(arg) do
        v = tostring(v)
        t[#t+1] = '$'..#v
        t[#t+1] = v
    end
    t[#t+1] = ""
    return tconcat(t, '\r\n')
end

local function read_response(channel)
    local line = channel:read('\r\n')
    local typ  = sbyte(line, 1)
    local data = ssub(line, 2)
    return __response_type[typ](channel, data)
end

local function login_auth(auth, db)
    return function(channel)
        if auth then
            channel:request(compose_command('auth', auth), read_response)
        end
        if db then
            channel:request(compose_command('select', db), read_response)
        end
    end
end

function redis.connect(opts)
    local channel = socketchannel.create{
        host = opts.host,
        port = opts.port,
        auth = login_auth(opts.auth, opts.db),
    }
    local ok, err = channel:connect()
    if not ok then
        error(sformat("Redis connect %s:%s fail %s", opts.host, opts.port, err))
    end
    return setmetatable({channel}, __meta)
end

__response_type[42] = function(channel, data) -- '*'
    local n = tonumber(data)
    if n < 0 then
        return true, nil
    end
    local bulk = {}
    local ok = true
    for i = 1,n do
        local ok, v = read_response(channel)
        if ok then
            bulk[i] = v
        else
            ok = false
        end
    end
    return ok, bulk
end

__response_type[36] = function(channel, data) -- '$'
    local n = tonumber(data)
    if n < 0 then
        return true, nil
    end
    local line = channel:read(n+2)
    return true, ssub(line, 1, -3)
end

__response_type[43] = function(channel, data) -- '+'
    return true, data
end

__response_type[45] = function(channel, data) -- '-'
    return false, data
end

__response_type[58] = function(channel, data) -- ':'
    return true, tonumber(data)
end

local function command(self, cmd, ...)
    return self[1]:request(compose_command(cmd, ...), read_response)
end

function __M:close() 
    self[1]:close() 
end

function __M:move(key, db) return command(self, 'move', key, db) == 1 end
function __M:smove(src, dest, member) return command(self, 'smove', src, dest, member) == 1 end
function __M:exists(...) return command(self, 'exists', ...) == 1 end
function __M:hexists(key, field) return command(self, 'hexists', key, field) == 1 end
function __M:sismember(key, member) return command(self, 'sismember', key, member) == 1 end

function __M:multiexec(func)
    self:multi()
    pcall(func)
    return self:exec()
end

setmetatable(__M, { __index = function(t, k)
    local f = function(self, ...)
        return command(self, k, ...)
    end
    t[k] = f
    return f
end})

local __M_watch = {}
local __watch_meta = {
    __index = __M_watch,
    __gc = function(self)
        self[1]:close()
    end
}

local function watch_auth(self, auth)
    return function(channel)
        if auth then
            channel:request(compose_command('auth', auth), read_response)
        end
        for k, v in pairs(self.__sub_list) do
            channel:request(compose_command('subscribe', v))
        end
        for k, v in pairs(self.__psub_list) do
            channel:request(compose_command('psubscribe', v))
        end
    end
end

function redis.watch(opts)
    local self = {
        __sub_list = {},
        __psub_list = {},
    }
    local channel = socketchannel.create {
        host = opts.host,
        port = opts.port,
        auth = watch_auth(self),
    }
    self[1] = channel
    return setmetatable(self, __watch_meta)
end


local function watch_func(name)
    __M_watch[name] = function(self, ...)
        local arg = {...}
        for k, v in ipairs(arg) do
            self[1]:request(compose_command(name, v))
        end
    end
end

watch_func('subscribe')
watch_func('psubscribe')
watch_func('unsubscribe')
watch_func('punsubscribe')

function __M_watch:message()
    local channel = self[1]
    while true do
        local r = channel:response(read_response)
        local typ, ch, data, data2 = r[1], r[2], r[3], r[4]
        if typ == 'message' then
            return data, ch
        elseif typ == 'pmessage' then
            return data2, data, ch
        elseif typ == 'subscribe' then
            self.__sub_list[ch] = true
        elseif typ == 'psubscribe' then
            self.__psub_list[ch] = true
        elseif typ == 'unsubscribe' then
            self.__sub_list[ch] = nil
        elseif typ == 'punsubscribe' then
            self.__psub_list[ch] = nil
        end
    end
end

return redis
