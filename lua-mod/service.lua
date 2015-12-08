local shaco = require "shaco"
local tonumber = tonumber
local assert = assert
local corunning = coroutine.running
local string = string
local table = table

local _slave_handle 
local _cache_q = {}

local CMD = {}

function CMD.QUERY(source, session, name)
    local global 
    if string.byte(name,1)==46 then --'.' local query
        name = string.sub(name,2)
        global = false
    else
        global = true
    end
    local handle = tonumber(shaco.command('QUERY', name))
    if not handle then
        if global then 
            if _slave_handle then
                shaco.send(_slave_handle, 'lua','QUERY', name) 
            end
        end
        local ql = _cache_q[name]
        if not ql then
            ql = {}
            _cache_q[name] = ql
        end
        local co = corunning()
        table.insert(ql, co)
        shaco.wait()
        handle = tonumber(shaco.command('QUERY', name))
        assert(handle)
    end
    shaco.ret(session, source, shaco.pack(handle))
end

function CMD.REG(source, session, param)
    local t, name, handle = assert(string.match(param, '(%.?)([%w%_]+) (%d+)'))
    handle = tonumber(handle)

    shaco.command('REG', name..' '..handle)
    if t~='.' then
        if _slave_handle then
            shaco.send(_slave_handle, 'lua', 'REG', name, handle)
        end
    end
    -- ret null, just wakeup session call
    shaco.ret(session, source, shaco.pack())
    local ql = _cache_q[name]
    if ql then
        while #ql > 0 do
            local co = table.remove(ql, 1)
            shaco.wakeup(co)
        end
    end
end

shaco.start(function()
    _slave_handle = tonumber(shaco.command('QUERY', 'slave'))
    shaco.dispatch("lua", function(source, session, type, param) 
        local func = CMD[type]
        if func then
            func(source, session, param)
        end
    end)
end)
