local shaco = require "shaco"
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

-- read: return nil to break loop
function commandline.loop(read, response)
    local loop = true
    while loop do 
        local ok, err = xpcall(function()
            local cmdline = read()
            if cmdline == nil then
                loop = false
            elseif #cmdline > 0 then
                if string.byte(cmdline,1)==58 then --':'
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
        end
    end
end

function commandline.expand_path(path)
    _expand_path = path
end

return commandline
