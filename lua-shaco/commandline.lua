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
local _expand

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
    assert(shaco.luaservice(name..' '..args))
end

function command.load(response, name)
    assert(name, 'no name')
    command.unload() -- unload last one

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
    assert(type(h.handle)=='function', 'no handle')
    if h.init then
        local ok, err = xpcall(h.init, debug.traceback, response)
        if not ok then
            response(err)
            if h.fini then
                h.fini()
            end
            return
        end
    end
    _expand = h
end

function command.unload(response)
    if _expand then
        if _expand.fini then
            _expand.fini()
        end
        _expand = nil
    end
end

local function handle_private(response, cmdline)
    local args = {}
    for w in string.gmatch(cmdline, '[%w%._]+') do
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

function commandline.start(read, response)
    shaco.fork(function()
        while true do 
            local ok, err = xpcall(function()
                local cmdline = read()
                if cmdline and #cmdline > 0 then
                    local private = false
                    if string.byte(cmdline,1)==46 then --'.'
                        private = true
                        cmdline = string.sub(cmdline,2)
                    end
                    if _expand and not private then
                        _expand.handle(response, cmdline)
                    else
                        handle_private(response, cmdline)
                    end
                end
            end, debug.traceback)
            if not ok then
                shaco.error(err)
            end
        end
    end)
end

function commandline.expand_path(path)
    _expand_path = path
end

return commandline
