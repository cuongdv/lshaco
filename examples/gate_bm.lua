local shaco = require "shaco"
local socket = require "socket"
local sunpack = string.unpack
local spack = string.pack

local nclient, nmsg = ...
nclient = tonumber(nclient)
nmsg = tonumber(nmsg)
--local temp = string.rep('0', 1024)
local temp = 'PING\r\n'
local nclose = 0
local nerror = 0
local nstat = 0
local start_time

local function sendpackage(id, s)
    assert(socket.send(id, spack('>I2', #s)..s))
end

local function readpackage(id)
    local head = assert(socket.read(id, 2))
    assert(socket.read(id, sunpack('>I2', head))) 
end

local function client(addr)
    local id
    local ok, err = pcall(function()
        id = assert(socket.connect(addr))
        shaco.sleep(10)
        socket.readon(id)
        for i=1, nmsg do
            sendpackage(id, temp)
            readpackage(id)

            nstat = nstat + 1
            if nstat % 10000 == 0 then
                local elapsed = (shaco.now()-start_time)/1000
                io.stdout:write('qps: '..nstat/elapsed..'\r')
                io.stdout:flush()
            end
        end
    end)
    if id then
        socket.close(id)
    end
    if not ok then
        print (err)
        nerror = nerror + 1
    end
    nclose = nclose + 1
    if nclose >= nclient then
        local elapsed = (shaco.now()-start_time)/1000
        shaco.info(string.format('error: %d, use time: %.2f, qps: %.2f', nerror, elapsed, nstat/elapsed))
    end
end

shaco.start(function()
    shaco.info('client: '..nclient, 'msg: '..nmsg)
    start_time = shaco.now()
    local addr = '127.0.0.1:1234'
    for i=1, nclient do
        shaco.fork(client, addr)
    end
end)
