local c = require "shaco.c"
local serialize = require "serialize.c"
local error = error
local pairs = pairs
local ipairs = ipairs
local tostring = tostring
local tonumber = tonumber
local assert = assert
local sformat = string.format
local tunpack = table.unpack
local tremove = table.remove
local tinsert = table.insert
local tconcat = table.concat
local cocreate = coroutine.create
local coresume = coroutine.resume
local coyield = coroutine.yield
local corunning = coroutine.running
local traceback = debug.traceback

local c_log = assert(c.log)
local c_send = assert(c.send)
local c_timer = assert(c.timer)

local _co_pool = {}
local _call_session = {}
local _yield_session_co = {}
local _sleep_co = {}
local _response_co_session = {}
local _response_co_address = {}

local _session_id = 0
local _fork_queue = {}
local _wakeup_co = {}

-- proto type
local proto = {}
local shaco = {
    TTEXT = 1,
    TLUA = 2,
    --TMONITOR = 3,
    --TLOG = 4,
    --TCMD = 5,
    TRESPONSE = 6,
    TSOCKET = 7,
    TTIME = 8,
    --TREMOTE = 9,
    TERROR = 10,
}

-- log
local LOG_DEBUG   =0
local LOG_TRACE   =1
local LOG_INFO    =2
local LOG_WARNING =3
local LOG_ERROR   =4

local function log(level, ...) 
    local argv = {...}
    local t = {}
    for _, v in ipairs(argv) do
        tinsert(t, tostring(v))
    end
    c_log(level, tconcat(t, ' '))
end

shaco.error   = function(...) log(LOG_ERROR, ...) end
shaco.warning = function(...) log(LOG_WARNING, ...) end
shaco.info    = function(...) log(LOG_INFO, ...) end
shaco.trace   = function(...) log(LOG_TRACE, ...) end
shaco.debug   = function(...) log(LOG_DEBUG, ...) end

shaco.now = assert(c.now)
shaco.command = assert(c.command)
shaco.handle = assert(c.handle)
shaco.tostring = assert(c.tostring)
shaco.topointstring = assert(c.topointstring)
shaco.packstring = assert(serialize.serialize_string)
shaco.unpackstring = assert(serialize.deserialize_string)
function shaco.pack(...) return serialize.serialize(serialize.pack(...)) end
function shaco.unpack(p,sz) return serialize.deserialize(p) end

local function gen_session()
    _session_id = _session_id + 1
    if _session_id > 0xffffffff then
        _session_id = 1
    end
    return _session_id
end

local suspend

local function co_create(func)
    local co = tremove(_co_pool)
    if co == nil then
        co = cocreate(function(...)
            func(...)
            while true do
                func = nil
                _co_pool[#_co_pool+1] = co
                func = coyield('EXIT')
                func(coyield())
            end
        end)
    else
        coresume(co, func)
    end
    return co
end

function shaco.send(dest, typename, ...)
    local p = proto[typename]
    return c_send(dest, 0, p.id, p.pack(...))
end

function shaco.call(dest, typename, ...)
    local p = proto[typename]
    local session = gen_session()
    if not c_send(dest, session, p.id, p.pack(...)) then
        error('call error')
    end
    local ok, ret, sz = coyield('CALL', session)
    _sleep_co[corunning()] = nil
    _call_session[session] = nil
    if not ok then
        -- todo BREAK can use for timeout call
        error('call error')
    end
    return p.unpack(ret, sz)
end

function shaco.ret(msg, sz)
    return coyield('RETURN', msg, sz)
end

function shaco.response(pack)
    pack = pack or shaco.pack
    return coyield('RESPONSE', pack)
end

local function dispatch_wakeup()
    local co = next(_wakeup_co)
    if co then
        _wakeup_co[co] = nil
        local session = _sleep_co[co]
        if session then
            -- _yield_session_co if tag _sleep_co can break by wakeup
            _yield_session_co[session] = 'BREAK' 
            return suspend(co, coresume(co, false, 'BREAK'))
        end
    end
end

function suspend(co, result, command, param, sz)
    if not result then
        local session = _response_co_session[co]
        if session then
            local address = _response_co_address[co]
            _response_co_session[co] = nil
            _response_co_address[co] = nil
            _response_sessoin[session] = nil
            c_send(address, session, shaco.TERROR, "")
        end
        error(traceback(co, command))
    end
    if command == 'SLEEP' then
        _yield_session_co[param] = co
        _sleep_co[co] = param
    elseif command == 'CALL' then
        _call_session[param] = true
        _yield_session_co[param] = co
        --_sleep_co[co] = param -- todo: no support BREAK yet
    elseif command == 'RETURN' then
        local session = _response_co_session[co]
        local address = _response_co_address[co]
        if not session then
            error('No session to response')
        end
        local ret = c_send(address, session, shaco.TRESPONSE, param, sz)
        _response_co_session[co] = nil
        _response_co_address[co] = nil
        return suspend(co, coresume(co, ret))
    elseif command == 'RESPONSE' then
        local session = _response_co_session[co]
        local address = _response_co_address[co]
        if not session then
            error(traceback(co, 'Already responsed or No session to response'))
        end
        local f = param
        local function response(...)
            if not f then
                error('Try response repeat')
            end
            local ret = c_send(address, session, shaco.TRESPONSE, f(...))
            f = nil
            return ret
        end
        _response_co_session[co] = nil
        _response_co_address[co] = nil
        return suspend(co, coresume(co, response))
    elseif command == 'EXIT' then
        local session = _response_co_session[co]
        if session then
            local address = _response_co_address[co]
            _response_co_session[co] = nil 
            _response_co_address[co] = nil 
            c_send(address, session, shaco.TERROR, "") 
        end
    else
        error(traceback(co, 'Suspend unknown command '..command))
    end
    return dispatch_wakeup()
end

local function dispatch_message(source, session, typeid, msg, sz)
    if typeid == 8 or -- shaco.TTIME
       typeid == 6 then -- shaco.TRESPONSE 
        local co = _yield_session_co[session] 
        if co == 'BREAK' then -- BREAK by wakeup yet
            _yield_session_co[session] = nil 
        elseif co == nil then
            error(sformat('unknown response %d session %d from %04x', typeid, session, source))
        else
            _yield_session_co[session] = nil
            suspend(co, coresume(co, true, msg, sz))
        end
    elseif typeid == 10 then -- shaco.TERROR
        if _call_session[session] then
            local co = _yield_session_co[session] 
            if co == 'BREAK' then -- BREAK by wakeup yet
                _yield_session_co[session] = nil 
            elseif co == nil then
                error(sformat('unknown error session %d from %04x', session, source))
            else
                _yield_session_co[session] = nil
                suspend(co, coresume(co, false))
            end
        else
            error(sformat('unknown error session %d from %04x', session, source))
        end
    else
        local p = proto[typeid]
        local co = co_create(p.dispatch)
        if session > 0 then
            _response_co_session[co] = session
            _response_co_address[co] = source
        end
        suspend(co, coresume(co, source, session, p.unpack(msg, sz)))
    end

end

local function dispatchcb(source, session, typeid, msg, sz)
    local ok, err = xpcall(dispatch_message, traceback, source, session, typeid, msg, sz)
    while true do
        local key, co = next(_fork_queue)
        if not key then
            break
        end
        _fork_queue[key] = nil
        local fok, ferr = xpcall(suspend, traceback, co, coresume(co))
        if not fok then
            if ok then
                ok = false
                err = ferr
            else
                err = err..'\n'..ferr 
            end
        end
    end
    if not ok then
        error(err)
    end
end

function shaco.fork(func, ...)
    local args = {...}
    local co = co_create(function()
        func(tunpack(args))
    end)
    tinsert(_fork_queue, co)
    return co
end

function shaco.wakeup(co)
    if _sleep_co[co] then
        if _wakeup_co[co] == nil then
            _wakeup_co[co] = true
        end
    else
        error('Try wakeup untag sleep coroutine')
    end
end

function shaco.wait()
    local session = gen_session()
    coyield('SLEEP', session)
    _sleep_co[corunning()] = nil
    _yield_session_co[session] = nil
end

function shaco.sleep(interval)
    local session = gen_session()
    c_timer(session, interval)
    local ok, ret = coyield('SLEEP', session)
    _sleep_co[corunning()] = nil
    if ok then
        return
    else
        if ret == 'BREAK' then
            return ret
        else
            error(ret)
        end
    end
end

function shaco.timeout(interval, func)
    local co = co_create(func)
    local session = gen_session()
    assert(_yield_session_co[session] == nil, 'Repeat session '..session)
    _yield_session_co[session] = co
    c_timer(session, interval)
end

function shaco.dispatch(protoname, fun)
    local p = proto[protoname]
    p.dispatch = fun
end

function shaco.start(func)
    c.callback(dispatchcb)
    shaco.timeout(0, function()
        local ok, err = xpcall(func, debug.traceback)
        if ok then
            shaco.send('.launcher', 'lua', 'LAUNCHOK')
        else
            shaco.error('init fail: ', err)
            shaco.send('.launcher', 'lua', 'LAUNCHFAIL')
        end
    end)
end

function shaco.kill(name)
    shaco.command('KILL', name)
end

function shaco.abort(info)
    shaco.command('ABORT', info or 'by lua')
end

function shaco.register_protocol(class)
    if proto[class.id] then
        error("Repeat protocol id "..tostring(class.id))
    end
    if proto[class.name] then
        error("Repeat protocol name "..tostring(class.name))
    end
    proto[class.id] = class
    proto[class.name] = class
end

shaco.register_protocol {
    id = shaco.TTIME,
    name = "time",
}

shaco.register_protocol {
    id = shaco.TRESPONSE,
    name = "response",
}

shaco.register_protocol  {
    id = shaco.TERROR,
    name = "error",
}

shaco.register_protocol {
    id = shaco.TTEXT,
    name = "text",
    pack = function(...) return ... end,
    unpack = shaco.tostring
}

shaco.register_protocol {
    id = shaco.TLUA,
    name = "lua",
    pack = shaco.pack,
    unpack = shaco.unpack
}

function shaco.getenv(key)
    return shaco.command('GETENV', key)
end

function shaco.newservice(name)
    return shaco.call('.launcher', 'lua', 'LAUNCH', name)
end

function shaco.uniqueservice(name)
    -- todo uniqueservice
    local mod_name = string.match(name, '([%w_]+)')
    local handle = tonumber(shaco.command('QUERY', mod_name))
    return handle or shaco.newservice(name)
end

function shaco.queryservice(name)
    return assert(shaco.call('.service', 'lua', 'QUERY', name))
end

function shaco.register(name, handle)
    shaco.call('.service', 'lua', 'REG', name..' '..handle or shaco.handle())
end

return shaco
