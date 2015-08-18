local shaco = require "shaco"
local socket = require "socket"

local socket_error = setmetatable({}, 
    {__tostring = function() return "[socket error]" end})
local function socket_assert(r, err)
    if not r then
        error(socket_error)
    else
        return r
    end
end

local C = {}
local R = {}
local CN = false

local function read_result(id)
    local h = assert(socket.read(id, "*2"))
    local s = assert(socket.read(id, h))
    return s
end

local function host()
    local host = shaco.getenv("host") or "0.0.0.0:7998"
    local ip, port = host:match("^([^:]+):?(%d+)$")
    local lid = assert(socket.listen(ip, port))
    shaco.info("[start] ch listen on "..host)
    socket.start(lid, function(id)
        socket.readenable(lid, false)
        shaco.fork(function()
            local ok, err = pcall(function()
                shaco.info ("[login] chicken")
                CN = true
                socket.start(id)
                socket.readenable(id, true)
                local cmd, len, ret
                while true do
                    cmd = table.remove(C,1)
                    if cmd then
                        shaco.info ("[cmd send] "..cmd)
                        assert(socket.send(id, cmd..'\n'))
                        while true do
                            len = assert(socket.read(id, "*2"))
                            if len > 0 then
                                ret = assert(socket.read(id, len))
                                table.insert(R, ret)
                            else
                                table.insert(R, 0) -- end of package
                                break
                            end
                        end
                        shaco.info ("[ret read] ok")
                    else
                        shaco.sleep(1)
                    end
                end
            end)
            if not ok then
                socket.close(id)
                socket.readenable(lid, true)
                CN = false
                error(err)
            end
        end)
    end)
end

local WAIT_RET = false

local function response(id)
    if CN then
        while CN do
            local ret = table.remove(R,1)
            if ret == 0 then -- end of package
                break
            elseif ret then
                socket_assert((socket.send(id, ret..'\r\n')))
            else 
                shaco.sleep(1)
            end
        end
    else
        socket_assert(socket.send(id, "[X] chicken disconected\r\n"))
    end
    WAIT_RET = false -- end of package or CN disconnected
end

local function controller()
    local host = shaco.getenv("controller") or "127.0.0.1:7997"
    local ip, port = host:match("^([^:]+):?(%d+)$")
    local lid = assert(socket.listen(ip, port))
    shaco.info("[start] cc listen on "..host)
    socket.start(lid, function(id)
        socket.readenable(lid, false)
        shaco.fork(function()
            local ok, err = pcall(function()
                shaco.info ("[login] controller")
                socket_assert((socket.send(id, "welcome to CH\r\n")))
                if WAIT_RET then
                    response(id)
                end
                socket_assert(socket.send(id, "chicken node>\r\n"))
                socket.start(id)
                socket.readenable(id, true)
                local cmd, ret
                while true do
                    cmd = socket_assert((socket.read(id, "\r\n")))
                    socket.readenable(id, false)
                    if #cmd > 0 then
                        shaco.info ("[cmd read] "..cmd, #cmd)
                        table.insert(C, cmd)
                        WAIT_RET = true
                        response(id)
                        shaco.info ("[ret send] ok")
                    end
                    socket_assert(socket.send(id, "chicken node>\r\n"))
                    socket.readenable(id, true)
                end
            end)
            if not ok then
                socket.close(id)
                socket.readenable(lid, true)
                error(err)
            end
        end)
    end)
end

shaco.start(function()
    shaco.fork(host)
    shaco.fork(controller)
end)
