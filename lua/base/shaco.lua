local c = require "shaco.c"
local socket = require "socket.c"
local memory = require "memory.c"
local serialize = require "serialize.c"
local util = require "util.c"
local ipairs = ipairs
local tostring = tostring
local sfmt = string.format
local tinsert = table.insert
local tconcat = table.concat

-- proto type
local proto = {}
local shaco = {
    PTYPE_TEXT = 1,
    PTYPE_UM   = 2,
    PTYPE_MONITOR = 3,
    PTYPE_LOG = 4,
    PTYPE_CMD = 5,
    PTYPE_RET = 6,
    PTYPE_SOCKET = 7,
    PTYPE_TIME = 8,
}

local __fork_queue = {}
local __wakeup_map = {}
local __wakeup_queue = {}
local __wakeuping

local function fix_um_dispatch(f)
    return function(session, source, ...)
        local co = coroutine.create(
            function(session, source, ...)
                --shaco.sleep(0)
                assert(xpcall(f, debug.traceback, session, source, ...))
            end)
        assert(coroutine.resume(co, session, source, ...))
    end
end

function shaco.register_protocol(class)
    assert(not proto[class.id], string.format("repeat protocol id %d", class.id))
    assert(not proto[class.name], string.format("repeat protocol name %s", class.name))
    proto[class.id] = class
    proto[class.name] = class
end

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
shaco.getloglevel = c.getloglevel
shaco.setloglevel = c.setloglevel

shaco.getenv = c.getenv

shaco.now = c.now
shaco.time = c.time
shaco.starttime = c.starttime

--shaco.pack = serialize.pack
--shaco.unpack = serialize.unpack
function shaco.pack(...)
    return serialize.serialize(serialize.pack(...))
end

function shaco.unpack(p,sz)
    return serialize.deserialize(p)
end

shaco.unpack_msgid = socket.unpack_msgid
shaco.sendpack_um = socket.sendpack_um

shaco.subscribe = c.subscribe
shaco.publish = c.publish
shaco.queryid = c.queryid

local monitor_map = {}
function shaco.uniquemodule(name, active, eventcb)
    local co = coroutine.running()
    local vhandle, published = c.uniquemodule(name, active)
    if published then
        if eventcb then
            eventcb("START", vhandle)
        end
    else
        monitor_map[name] = { co=co, eventcb=eventcb }
        coroutine.yield()
    end
    return vhandle
end

shaco.broadcast = c.broadcast
shaco.sendraw = c.sendraw

function shaco.send(dest, msg, sz)
    return c.send(0, nil, dest, shaco.PTYPE_UM, msg, sz)
end
function shaco.ret(session, dest, msg, sz)
    return c.send(session, nil, dest, shaco.PTYPE_RET, msg, sz)
end

local session_map = {}
local session_id = 0
local time_map = {}
local time_id = 0
local __timeout_func
local __timeout_interval

function shaco.call(dest, name, v)
    local co, ismain = coroutine.running()
    assert(ismain==false, "shaco.call should not in main coroutine")
    session_id = session_id + 1
    if session_id > 0xffffffff then
        session_id = 1
    end
    session_map[session_id] = co
    c.send(session_id, nil, dest, shaco.PTYPE_UM, shaco.pack(name, v))
    local session, msg, sz = coroutine.yield()
    session_map[session] = nil
    return shaco.unpack(msg, sz)
end

local function dispatch_wakeup()
    if not __wakeuping then
        while #__wakeup_queue > 0 do
            local co = table.remove(__wakeup_queue, 1)
            __wakeup_map[co] = nil
            __wakeuping = co
            assert(coroutine.resume(co))
            __wakeuping = nil
        end
    end
end

local function dispatch_task()
    dispatch_wakeup()
    while #__fork_queue > 0 do
        local co = table.remove(__fork_queue, 1)
        assert(coroutine.resume(co))
        dispatch_wakeup()
    end
end

local function dispatchcb(session, source, ptype, msg, sz)
    local p = proto[ptype]
    assert(p and p.dispatch, string.format("invaid proto type %d", ptype))
    p.dispatch(session, source, p.unpack(msg, sz))
    dispatch_task()
end

function shaco.fork(f, ...)
    local args = {...}
    local co = coroutine.create(function()
        assert(xpcall(f, debug.traceback, table.unpack(args)))
    end)
    table.insert(__fork_queue, co)
    return co
    --assert(coroutine.resume(co, ...))
end

function shaco.wakeup(co)
    if __wakeup_map[co] == nil then
        __wakeup_map[co] = true
        table.insert(__wakeup_queue, co)
    end
end

-- CMD
local __CMD = {}
__CMD.help = function()
    local t = {""}
    for k, v in pairs(__CMD) do
        if type(v) == "function" then
            table.insert(t, k)
        end
    end
    return table.concat(t, "\n____ ")
end

__CMD.gc = function()
    local m1 = collectgarbage("count")
    collectgarbage("collect")
    local m2 = collectgarbage("count")
    return string.format("%f <- %f", m2, m1)
end

__CMD.mem = function()
    memory.stat()
    return string.format("used(%fK) lua(%fK)", memory.used()/1024, collectgarbage("count"))
end

local function __cmdr(source, id, result, pure)
    shaco.send(source, shaco.pack(id, "RES", result, pure))
end

local function __cmdcall(source, id, s)
    local args = {}
    for w in string.gmatch(s, "%g+") do
        table.insert(args, w)
    end
    if #args == 0 then
        __cmdr(source, id, "no input")
    else
        local f = __CMD[args[1]]
        if f then
            __cmdr(source, id, select(2, pcall(f, select(2, table.unpack(args)))))
        else
            __cmdr(source, id, "no found command")
        end
    end
end

function shaco.register_command(cmd)
    for k, v in pairs(cmd) do
        __CMD[k] = v
    end
end

shaco.register_protocol {
    id = shaco.PTYPE_CMD,
    name = "cmd",
    unpack = shaco.unpack,
    dispatch = function(_, source, id, s)
        __cmdcall(source, id, s)
    end
}

shaco.register_protocol {
    id = shaco.PTYPE_MONITOR,
    name = "monitor",
    unpack = function(msg,sz)
        local s = util.bytes2str(msg,sz)
        return string.unpack("i1zi4",s)
    end,
    dispatch = function(_, _, type, name, vhandle)
        if type == 0 then -- MONITOR_START
            local mo = monitor_map[name]
            local co = mo.co
            if mo.eventcb then
                mo.eventcb("START", vhandle)
            end
            if co then
                mo.co = nil
                shaco.wakeup(co)
            end
        elseif type == 1 then -- MONITOR_EXIT
            local mo = monitor_map[name]
            if mo.eventcb then
                mo.eventcb("EXIT", vhandle)
            end
        end
    end
}

shaco.register_protocol {
    id = shaco.PTYPE_TIME,
    name = "time",
    unpack = function() end,
    dispatch = function(session,_)
        if session == 0 then
            __timeout_func()
            c.timer(0, __timeout_interval)
        else
            local co = time_map[session]
            assert(coroutine.resume(co, session))
        end
    end
}

shaco.register_protocol {
    id = shaco.PTYPE_UM,
    name = "um",
    unpack = shaco.unpack,
    dispatch = nil
}

shaco.register_protocol {
    id = shaco.PTYPE_RET,
    name = "ret",
    unpack = function(...) return ... end,
    dispatch = function(session,_,msg,sz) 
        local co = session_map[session]
        assert(coroutine.resume(co, session, msg, sz))
    end
}

function shaco.dispatch(protoname, fun)
    local p = proto[protoname]
    if p.id == shaco.PTYPE_UM then 
        p.dispatch = fix_um_dispatch(fun)
    else 
        p.dispatch = fun
    end
end

function shaco.sleep(interval)
    local co = coroutine.running()
    time_id = time_id + 1
    if time_id > 0xffffffff then
        time_id = 1
    end
    time_map[time_id] = co
    c.timer(time_id, interval)
    local id = coroutine.yield()
    time_map[id] = nil
end

function shaco.timeout(interval, func)
    __timeout_func = func
    __timeout_interval = interval
    c.timer(0, interval)
end

function shaco.start(f)
    c.main(dispatchcb)
    shaco.fork(f)
    dispatch_task()
end

return shaco
