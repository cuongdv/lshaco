local c = require "shaco.c"
local socket = require "socket.c"
--local memory = require "memory.c"
local serialize = require "serialize.c"
local ipairs = ipairs
local tostring = tostring
local sfmt = string.format
local tinsert = table.insert
local tconcat = table.concat

local _suspend_co_map = {}
local _session_id = 0
local _fork_queue = {}
local _wakeup_map = {}
local _wakeup_queue = {}
local _wakeuping

-- proto type
local proto = {}
local shaco = {
    TTEXT = 1,
    TLUA   = 2,
    TMONITOR = 3,
    TLOG = 4,
    TCMD = 5,
    TRET = 6,
    TSOCKET = 7,
    TTIME = 8,
}

-- log
local LOG_DEBUG   =0
local LOG_TRACE   =1
local LOG_INFO    =2
local LOG_WARNING =3
local LOG_ERROR   =4

function shaco.log(level, ...) 
    local argv = {...}
    local t = {}
    for _, v in ipairs(argv) do
        tinsert(t, tostring(v))
    end
    c.log(level, tconcat(t, ' '))
end

shaco.error   = function(...) shaco.log(LOG_ERROR, ...) end
shaco.warning = function(...) shaco.log(LOG_WARNING, ...) end
shaco.info    = function(...) shaco.log(LOG_INFO, ...) end
shaco.trace   = function(...) shaco.log(LOG_TRACE, ...) end
shaco.debug   = function(...) shaco.log(LOG_DEBUG, ...) end

shaco.now = c.now
shaco.command = c.command
shaco.handle = c.handle

function shaco.pack(...)
    return serialize.serialize(serialize.pack(...))
end

function shaco.unpack(p,sz)
    return serialize.deserialize(p)
end

--shaco.unpack_msgid = socket.unpack_msgid
--shaco.sendpack_um = socket.sendpack_um

--shaco.subscribe = c.subscribe
--shaco.publish = c.publish
--shaco.queryid = c.queryid

--local monitor_map = {}
--function shaco.uniquemodule(name, active, eventcb)
--    local co = coroutine.running()
--    local vhandle, published = c.uniquemodule(name, active)
--    if published then
--        if eventcb then
--            eventcb("START", vhandle)
--        end
--    else
--        monitor_map[name] = { co=co, eventcb=eventcb }
--        coroutine.yield()
--    end
--    return vhandle
--end

--shaco.broadcast = c.broadcast
--shaco.sendraw = c.sendraw

local function co_create(func)
    return coroutine.create(func)
end

--local function fix_um_dispatch(f)
--    return function(session, source, ...)
--        local co = coroutine.create(
--            function(session, source, ...)
--                assert(xpcall(f, debug.traceback, session, source, ...))
--            end)
--        assert(coroutine.resume(co, session, source, ...))
--    end
--end

function shaco.register_protocol(class)
    if proto[class.id] then
        error("repeat protocol id "..tostring(class.id))
    end
    if proto[class.name] then
        error("repeat protocol name "..tostring(class.name))
    end
    proto[class.id] = class
    proto[class.name] = class
end


function shaco.send(dest, msg, sz)
    return c.send(nil, dest, 0, shaco.TLUA, msg, sz)
end
function shaco.ret(session, dest, msg, sz)
    return c.send(nil, dest, session, shaco.TRET, msg, sz)
end

local function gen_session()
    _session_id = _session_id + 1
    if _session_id > 0xffffffff then
        _session_id = 1
    end
    return _session_id
end

function shaco.call(dest, typename, ...)
    local p = proto[typename]
    local co, ismain = coroutine.running()
    assert(ismain==false, "shaco.call should not in main coroutine")
    local session, msg, sz
    session = gen_session()
    assert(_suspend_co_map[session] ==nil)
    _suspend_co_map[session] = co
    c.send(nil, dest, session, p.id, shaco.pack(...))
    session, msg, sz = coroutine.yield()
    _suspend_co_map[session] = nil
    return shaco.unpack(msg, sz)
end

local function dispatch_wakeup()
    if not _wakeuping then
        while #_wakeup_queue > 0 do
            local co = table.remove(_wakeup_queue, 1)
            _wakeup_map[co] = nil
            _wakeuping = co
            assert(coroutine.resume(co))
            _wakeuping = nil
        end
    end
end

local function dispatch_task()
    dispatch_wakeup()
    while #_fork_queue > 0 do
        local co = table.remove(_fork_queue, 1)
        assert(coroutine.resume(co))
        dispatch_wakeup()
    end
end

local function dispatchcb(source, session, typename, msg, sz)
    local p = proto[typename]
    if typename == 8 or -- shaco.TTIME or
       typename == 6 then -- shaco.TRET then
        p.dispatch(source, session, p.unpack(msg, sz))
    else
        local co = co_create(p.dispatch)
        assert(coroutine.resume(co, source, session, p.unpack(msg, sz)))
    end
    dispatch_task()
end

function shaco.fork(func, ...)
    local args = {...}
    local co = coroutine.create(function()
        assert(xpcall(func, debug.traceback, table.unpack(args)))
    end)
    table.insert(_fork_queue, co)
end

function shaco.wakeup(co)
    if _wakeup_map[co] == nil then
        _wakeup_map[co] = true
        table.insert(_wakeup_queue, co)
    end
end

function shaco.wait()
    return coroutine.yield()
end

function shaco.dispatch(protoname, fun)
    local p = proto[protoname]
    p.dispatch = fun
end

function shaco.sleep(interval)
    local co = coroutine.running()
    local session = gen_session()
    assert(_suspend_co_map[session]==nil)
    _suspend_co_map[session] = co
    c.timer(session, interval)
    session = coroutine.yield()
    _suspend_co_map[session] = nil
end

function shaco.timeout(interval, func)
    local co = co_create(func)
    local session = gen_session()
    assert(_suspend_co_map[session] == nil)
    _suspend_co_map[session] = co
    c.timer(session, interval)
end

function shaco.start(func)
    c.callback(dispatchcb)
    shaco.fork(func)
    dispatch_task()
end

-- CMD
--local __CMD = {}
--__CMD.help = function()
--    local t = {""}
--    for k, v in pairs(__CMD) do
--        if type(v) == "function" then
--            table.insert(t, k)
--        end
--    end
--    return table.concat(t, "\n____ ")
--end
--
--__CMD.gc = function()
--    local m1 = collectgarbage("count")
--    collectgarbage("collect")
--    local m2 = collectgarbage("count")
--    return string.format("%f <- %f", m2, m1)
--end
--
--__CMD.mem = function()
--    memory.stat()
--    return string.format("used(%fK) lua(%fK)", memory.used()/1024, collectgarbage("count"))
--end
--
--local function __cmdr(source, id, result, pure)
--    shaco.send(source, shaco.pack(id, "RES", result, pure))
--end
--
--local function __cmdcall(source, id, s)
--    local args = {}
--    for w in string.gmatch(s, "%g+") do
--        table.insert(args, w)
--    end
--    if #args == 0 then
--        __cmdr(source, id, "no input")
--    else
--        local f = __CMD[args[1]]
--        if f then
--            __cmdr(source, id, select(2, pcall(f, select(2, table.unpack(args)))))
--        else
--            __cmdr(source, id, "no found command")
--        end
--    end
--end
--
--function shaco.register_command(cmd)
--    for k, v in pairs(cmd) do
--        __CMD[k] = v
--    end
--end

shaco.register_protocol {
    id = shaco.TTIME,
    name = "time",
    unpack = function() end,
    dispatch = function(_,session)
        local co = _suspend_co_map[session]
        assert(coroutine.resume(co, session))
    end
}

--shaco.register_protocol {
--    id = shaco.TCMD,
--    name = "cmd",
--    unpack = shaco.unpack,
--    dispatch = function(source, _,id, s)
--        __cmdcall(source, id, s)
--    end
--}

--shaco.register_protocol {
--    id = shaco.TMONITOR,
--    name = "monitor",
--    unpack = function(msg,sz)
--        local s = util.bytes2str(msg,sz)
--        return string.unpack("i1zi4",s)
--    end,
--    dispatch = function(_, _, type, name, vhandle)
--        if type == 0 then -- MONITOR_START
--            local mo = monitor_map[name]
--            local co = mo.co
--            if mo.eventcb then
--                mo.eventcb("START", vhandle)
--            end
--            if co then
--                mo.co = nil
--                shaco.wakeup(co)
--            end
--        elseif type == 1 then -- MONITOR_EXIT
--            local mo = monitor_map[name]
--            if mo.eventcb then
--                mo.eventcb("EXIT", vhandle)
--            end
--        end
--    end
--}
--

shaco.register_protocol {
    id = shaco.TLUA,
    name = "lua",
    unpack = shaco.unpack,
    dispatch = nil
}

shaco.register_protocol {
    id = shaco.TRET,
    name = "ret",
    unpack = function(...) return ... end,
    dispatch = function(_,session,msg,sz) 
        local co = _suspend_co_map[session]
        assert(coroutine.resume(co, session, msg, sz))
    end
}

function shaco.getenv(key)
    return shaco.command('GETENV', key)
end

function shaco.luaservice(name)
    return tonumber(shaco.command('LAUNCH', 'lua '..name))
end

function shaco.queryservice(name)
    return shaco.call('.service', 'lua', 'QUERY', name)
end

function shaco.register(name)
    shaco.call('.service', 'lua', 'REG', name..' '..shaco.handle())
end

return shaco
