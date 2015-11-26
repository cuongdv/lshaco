local shaco = require "shaco"

local _cache_q = {}

local CMD = {}

function CMD.QUERY(source, session, name)
    local handle = tonumber(shaco.command('QUERY', name))
    if not handle then
        local ql = _cache_q[name]
        if not ql then
            ql = {}
            _cache_q[name] = ql
        end
        local co = coroutine.running()
        table.insert(ql, co)
        shaco.wait()
        handle = tonumber(shaco.command('QUERY', name))
        assert(handle)
    end
    shaco.ret(session, source, shaco.pack(handle))
end

function CMD.REG(source, session, param)
    local name, handle = assert(string.match(param, '([%w%.%_]+) ([%w%.%_]+)'), param)
    shaco.command('REG', param)
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
    shaco.dispatch("lua", function(source, session, type, param) 
        local func = CMD[type]
        if func then
            func(source, session, param)
        end
    end)
    local name = string.format('.service %d', shaco.handle())
    shaco.command('REG', name)
end)
