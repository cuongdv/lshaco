local shaco = require "shaco"
local tbl = require "tbl"
local table = table
local string = string
local sformat = string.format
local assert = assert
local select = select
local pairs = pairs
local type = type
local loadfile = loadfile
local debug = debug
local xpcall = xpcall
local pcall = pcall

local commandline = {}

local _expand_path 
local _expand = {}

local command = {}

function command.help()
    local t = {}
    for k,v in pairs(command) do
        t[#t+1] = '* '..k
    end
    return table.concat(t)
end

function command.time()
    local starttime = tonumber(shaco.command("STARTTIME")) // 1000
    local now = shaco.now() // 1000
    local elapsed = now - starttime
    starttime = os.date("%y%m%d-%H:%M:%S", starttime)
    now = os.date("%y%m%d-%H:%M:%S", now)

    local day, hour, min, sec
    day = elapsed // 86400
    elapsed = elapsed % 86400
    hour = elapsed // 3600
    elapsed = elapsed % 3600
    min = elapsed // 60
    sec = elapsed % 60

    return sformat("%dd%dh%dm%ss [%s ~ %s]", day, hour, min, sec, starttime, now)
end

function command.loglevel(level)
    if level then
        shaco.command("SETLOGLEVEL", level)
    end
    return shaco.command("GETLOGLEVEL")
end

function command.start(name, ...)
    assert(name, 'no name')
    local args = {...}
    args = table.concat(args, ' ')
    print("start newservice...",name)
    return assert(shaco.newservice(name..' '..args))
end

function command.load(name, ...)
    assert(name, 'no name')
    if _expand[name] then
        return 'Expand already load'
    end
    local func
    local errv = {}
    for pattern in string.gmatch(_expand_path, '([^;]+);*') do
        local fname = string.gsub(pattern, '?', name)
        local block, err = loadfile(fname)
        if not block then
            table.insert(errv, err)
        else
            func = block 
            break
        end
    end
    if not func then
        return table.concat(errv, '\n')
    end
    local ok, h = pcall(func)
    if not ok then
        return h
    end
    assert(h and type(h.handle)=='function', 'no handle')
    if h.init then
        local ok, err = xpcall(h.init, debug.traceback, ...)
        if not ok then
            if h.fini then
                h.fini()
            end
            return err
        end
    end
    _expand[name] = h
end

function command.unload(name)
    local h = _expand[name]
    if h then
        if h.fini then
            h.fini()
        end
        _expand[name] = nil
    end
end

local function handle_private(cmdline)
    if string.byte(cmdline,1)==58 then --':' mod
        cmdline = string.sub(cmdline, 2)
        local args = {}
        for w in string.gmatch(cmdline, "[^%s]+") do
            args[#args+1] = w
        end
        assert(#args >= 2, "Invalid command")
        local handle = assert(tonumber(shaco.command('QUERY', args[1])), "Invalid service")
        --local handle = shaco.queryservice(name) -- will block
        local value = shaco.call(handle, "lua", args[2], select(3, table.unpack(args)))
        if type(value) == "table" then
            return tbl(value, "result")
        else
            return tostring(value)
        end
    else
        local args = {}
        for w in string.gmatch(cmdline, '[^%s]+') do
            table.insert(args, w)
        end
        if #args > 0 then
            local func = command[args[1]]
            if func then
                return func(select(2, table.unpack(args)))
            else
                return "Unknown command "..args[1]
            end
        end
    end
end

-- read: return nil to break loop
function commandline.loop(read, response)
    local loop = true
    while loop do 
        local ok, err = xpcall(function()
            local cmdline = read()
            if cmdline == nil then
                loop = false
            elseif #cmdline > 0 then
                -- 过滤非法字符，例如telnet是\r\n的，\r会带到这里
                cmdline = string.match(cmdline, "([%g ]+)") 
                assert(cmdline, "Invalid command")
                if string.byte(cmdline,1)==43 then --'+' expand
                    local name, cmdline = string.match(cmdline, ':([%w%_]+)[ ]+(.+)')
                    if name and cmdline then
                        local h = _expand[name]
                        if h then
                            response(h.handle(cmdline))
                        else
                            response('No expand '..name)
                        end
                    end
                else
                    response(handle_private(cmdline))
                end
            end
        end, debug.traceback)
        if not ok then
            shaco.error(err)
            response("Catch error")
        end
    end
end

function commandline.expand_path(path)
    _expand_path = path
end

return commandline
