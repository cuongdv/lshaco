local shaco = require "shaco"
local socket = require "socket"

local console = {}

local _handle_path = './examples/?.lua'
local _handle

function console.help()
    for k,v in pairs(console) do
        print('* '..k)
    end
end

function console.start(name, ...)
    local args = {...}
    args = table.concat(args, ' ')
    assert(shaco.luaservice(name..' '..args))
end

function console.load(name)
    console.unload() -- unload last one

    local func
    local errv = {}
    for pattern in string.gmatch(_handle_path, '([^;]+);*') do
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
        print(table.concat(errv, '\n'))
        return
    end
    local ok, h = pcall(func)
    if not ok then
        print(h)
        return
    end
    assert(type(h.handle)=='function', 'no handle')
    if h.init then
        local ok, err = xpcall(h.init, debug.traceback)
        if not ok then
            print(err)
            if h.fini then
                h.fini()
            end
            return
        end
    end
    _handle = h
end

function console.unload()
    if _handle then
        if _handle.fini then
            _handle.fini()
        end
        _handle = nil
    end
end

local function handle_private(cmdline)
    local args = {}
    for w in string.gmatch(cmdline, '[%w%._]+') do
        table.insert(args, w)
    end
    if #args > 0 then
        local func = console[args[1]]
        if func then
            func(select(2, table.unpack(args)))
        else
            print("Unknown console command "..args[1])
        end
    end
end

shaco.start(function()
    local id = assert(socket.stdin())
    while true do 
        local ok, err = xpcall(function()
            local cmdline = assert(socket.read(id, '\n'))
            if #cmdline > 0 then
                local private = false
                if string.byte(cmdline,1)==46 then --'.'
                    private = true
                    cmdline = string.sub(cmdline,2)
                end
                if _handle and not private then
                    _handle.handle(cmdline)
                else
                    handle_private(cmdline)
                end
            end
        end, debug.traceback)
        if not ok then
            shaco.error(err)
        end
    end
end)
