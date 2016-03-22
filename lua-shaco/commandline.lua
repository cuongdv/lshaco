local shaco = require "shaco"
local tbl = require "tbl"
local table = table
local string = string
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

function command.help(response)
    for k,v in pairs(command) do
        response('* '..k)
    end
end

command[":"] = function(response, name, ...)
    local handle = shaco.queryservice(name)
    shaco.call(handle, "lua", ...)
end

function command.start(response, name, ...)
    assert(name, 'no name')
    local args = {...}
    args = table.concat(args, ' ')
    assert(shaco.newservice(name..' '..args))
end

function command.load(response, name, ...)
    assert(name, 'no name')
    if _expand[name] then
        response('Expand already load')
        return
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
        response(table.concat(errv, '\n'))
        return
    end
    local ok, h = pcall(func)
    if not ok then
        response(h)
        return
    end
    assert(h and type(h.handle)=='function', 'no handle')
    if h.init then
        local ok, err = xpcall(h.init, debug.traceback, response, ...)
        if not ok then
            response(err)
            if h.fini then
                h.fini()
            end
            return
        end
    end
    _expand[name] = h
end

function command.unload(response, name)
    local h = _expand[name]
    if h then
        if h.fini then
            h.fini()
        end
        _expand[name] = nil
    end
end

local function handle_private(response, cmdline)
    if string.byte(cmdline,1)==58 then --':' mod
        local pos = string.find(cmdline, ' ', 2, true)
        assert(pos and pos > 2, "Invalid command")
        local name = string.sub(cmdline, 2, pos-1)
        local cmd, param
        local pos2 = string.find(cmdline, ' ', pos+1, true)
        if pos2 then
            assert(pos2 > pos+1, "Invalid command")
            cmd = string.sub(cmdline, pos+1, pos2-1)
            param = string.sub(cmdline, pos2+1)
        else
            cmd = string.sub(cmdline, pos+1)
        end
        local handle = assert(tonumber(shaco.command('QUERY', name)), "Invalid service")
        --local handle = shaco.queryservice(name) -- will block
        local value = shaco.call(handle, "lua", cmd, param)
        if type(value) == "table" then
            response(tbl(value, "result"))
        else
            response(tostring(value))
        end
    else
        local args = {}
        for w in string.gmatch(cmdline, '[^%s]+') do
            table.insert(args, w)
        end
        if #args > 0 then
            local func = command[args[1]]
            if func then
                func(response, select(2, table.unpack(args)))
            else
                response("Unknown command command "..args[1])
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
                cmdline = string.match(cmdline, "([:_%w ]+)") 
                assert(cmdline, "Invalid command")
                if string.byte(cmdline,1)==43 then --'+' expand
                    local name, cmdline = string.match(cmdline, ':([%w%_]+)[ ]+(.+)')
                    if name and cmdline then
                        local h = _expand[name]
                        if h then
                            h.handle(response, cmdline)
                        else
                            response('No expand '..name)
                        end
                    end
                else
                    handle_private(response, cmdline)
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
