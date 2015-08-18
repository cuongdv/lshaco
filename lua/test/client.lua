local shaco = require "shaco"
local socket = require "socket"
local linenoise = require "linenoise"

shaco.start(function()
    local host = shaco.getenv("host")
    local ip, port = string.match(host, "([^:]+):?(%d+)$")
    local id, err = socket.connect(ip, port)
    assert(id, err)

    local mode
    local function code(s)
        assert(#mode > 0)
        if #mode > 1 and string.sub(mode, 1, 1) == "*" then
            local m = string.sub(mode, 2, 2)
            if m == '1' then
                assert(#s < 2^8)
                return string.char(
                bit32.extract(#s,0,8))..s
            elseif m == '2' then
                assert(#s < 2^16)
                return string.char(
                bit32.extract(#s,0,8), 
                bit32.extract(#s,8,8))..s
            elseif m == '4' then
                assert(#s < 2^32)
                return string.char(
                bit32.extract(#s,0,8), 
                bit32.extract(#s,8,8), 
                bit32.extract(#s,16,8),
                bit32.extract(#s,24,8))..s
            elseif m == 'a' then
                return s
            elseif m == 'l' then
                return s..'\n'
            end
        else
            return s..mode
        end
    end
    while true do
        mode = linenoise.linenoise("[set message mode] ")
        if mode == nil then
            os.exit(1)
        end
        if mode ~= "" then
            socket.send(id, mode.."\n")
            break
        end
    end
    while true do
        local s = linenoise.linenoise("> ")
        if s == nil then
            os.exit(1)
        end
        if s ~= "" then
            socket.send(id, code(s)) 
        end
    end
end)
