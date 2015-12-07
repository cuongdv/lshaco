local c = require "shaco.c"
local socket = require "socket.c"
--local memory = require "memory.c"
local serialize = require "serialize.c"
local error = error
local pairs = pairs
local ipairs = ipairs
local tostring = tostring
local tonumber = tonumber
local assert = assert
local xpcall = xpcall
local pcall = pcall
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
    TLUA = 2,
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
shaco.tostring = c.tostring
shaco.topointstring = c.topointstring
shaco.packstring = serialize.serialize_string
shaco.unpackstring = serialize.deserialize_string
function shaco.pack(...)
    return serialize.serialize(serialize.pack(...))
end
function shaco.unpack(p,sz)
    return serialize.deserialize(p)
end

--shaco.unpack_msgid = socket.unpack_msgid
--shaco.sendpack_um = socket.sendpack_um

--local monitor_map = {}
--function shaco.uniquemodule(name, active, eventcb)
--    local co = corunning()
--    local vhandle, published = c.uniquemodule(name, active)
--    if published then
--        if eventcb then
--            eventcb("START", vhandle)
--        end
--    else
--        monitor_map[name] = { co=co, eventcb=eventcb }
--        coyield()
--    end
--    return vhandle
--end

--shaco.broadcast = c.broadcast
--shaco.sendraw = c.sendraw

local function co_create(func)
    -- todo: conroutine cache pool
    return cocreate(function(...)
        assert(xpcall(func, traceback, ...))
    end)
    --return cocreate(func)
end

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

function shaco.send(dest, typename, ...)
    local p = proto[typename]
    return c.send(dest, 0, p.id, p.pack(...))
end

function shaco.ret(session, dest, msg, sz)
    local p = proto['ret']
    return c.send(dest, session, p.id, msg, sz)
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
    local co, ismain = corunning()
    assert(ismain==false, "shaco.call should not in main coroutine")
    local session, msg, sz
    session = gen_session()
    assert(_suspend_co_map[session] ==nil)
    _suspend_co_map[session] = co
    c.send(dest, session, p.id, p.pack(...))
    session, msg, sz = coyield()
    _suspend_co_map[session] = nil
    return p.unpack(msg, sz)
end

local function dispatch_wakeup()
    if not _wakeuping then
        while #_wakeup_queue > 0 do
            local co = tremove(_wakeup_queue, 1)
            _wakeup_map[co] = nil
            _wakeuping = co
            assert(coresume(co))
            _wakeuping = nil
        end
    end
end

local function dispatch_task()
    dispatch_wakeup()
    while #_fork_queue > 0 do
        local co = tremove(_fork_queue, 1)
        assert(coresume(co))
        dispatch_wakeup()
    end
end

local function dispatchcb(source, session, typeid, msg, sz)
    local p = proto[typeid]
    if typeid == 8 or -- shaco.TTIME or
       typeid == 6 then -- shaco.TRET then
        p.dispatch(source, session, msg, sz)
    else
--    return function(session, source, ...)
--        local co = cocreate(
--            function(session, source, ...)
--                assert(xpcall(f, traceback, session, source, ...))
--            end)
--        assert(coresume(co, session, source, ...))
--    end
        --local co = cocreate(
        --    function(...)
        --        assert(xpcall(p.dispatch, traceback, ...))
        --    end)
        local co = co_create(p.dispatch)
        assert(coresume(co, source, session, p.unpack(msg, sz)))
    end
    dispatch_task()
end

function shaco.fork(func, ...)
    local args = {...}
    local co = cocreate(function()
        --func(tunpack(args))
        assert(xpcall(func, traceback, tunpack(args)))
    end)
    tinsert(_fork_queue, co)
end

function shaco.wakeup(co)
    if _wakeup_map[co] == nil then
        _wakeup_map[co] = true
        tinsert(_wakeup_queue, co)
    end
end

function shaco.wait()
    return coyield()
end

function shaco.dispatch(protoname, fun)
    assert(fun)
    local p = proto[protoname]
    p.dispatch = fun
end

function shaco.sleep(interval)
    local co = corunning()
    local session = gen_session()
    assert(_suspend_co_map[session]==nil)
    _suspend_co_map[session] = co
    c.timer(session, interval)
    session = coyield()
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
--            tinsert(t, k)
--        end
--    end
--    return tconcat(t, "\n____ ")
--end
--
--__CMD.gc = function()
--    local m1 = collectgarbage("count")
--    collectgarbage("collect")
--    local m2 = collectgarbage("count")
--    return sformat("%f <- %f", m2, m1)
--end
--
--__CMD.mem = function()
--    memory.stat()
--    return sformat("used(%fK) lua(%fK)", memory.used()/1024, collectgarbage("count"))
--end
--
--local function __cmdr(source, id, result, pure)
--    shaco.send(source, shaco.pack(id, "RES", result, pure))
--end
--
--local function __cmdcall(source, id, s)
--    local args = {}
--    for w in string.gmatch(s, "%g+") do
--        tinsert(args, w)
--    end
--    if #args == 0 then
--        __cmdr(source, id, "no input")
--    else
--        local f = __CMD[args[1]]
--        if f then
--            __cmdr(source, id, select(2, pcall(f, select(2, tunpack(args)))))
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
        assert(coresume(co, session))
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

shaco.register_protocol {
    id = shaco.TRET,
    name = "ret",
    dispatch = function(_,session,msg,sz) 
        local co = _suspend_co_map[session]
        assert(coresume(co, session, msg, sz))
    end
}

function shaco.getenv(key)
    return shaco.command('GETENV', key)
end

function shaco.launch(name)
    return tonumber(shaco.command('LAUNCH', name))
end

function shaco.luaservice(name)
    return shaco.launch('lua '..name)
end

function shaco.queryservice(name)
    return assert(shaco.call('.service', 'lua', 'QUERY', name))
end

function shaco.register(name)
    shaco.call('.service', 'lua', 'REG', name..' '..shaco.handle())
end

function shaco.exit(info)
    shaco.command('EXIT', info or 'in lua')
end

return shaco
