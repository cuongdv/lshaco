local shaco = require "shaco"
local socket = require "socket"
local linenoise = require "linenoise"
local redis = require "redis"
local tbl = require "tbl"

shaco.start(function()
    local history_file = ".redis-cli.history"
    
    local ip = shaco.getenv("redis_host")
    local port = tonumber(shaco.getenv("redis_port"))
    local host = ip..":"..port
    local auth = shaco.getenv("redis_passwd")
    local db

    linenoise.loadhistory(history_file) 
    while true do
        local prompt = db and host or 'not connected'
        local s = linenoise.read(prompt..'> ',
            function() return io.stdin:read(1) end,
            function() return io.stdin:read("l") end)
        if s == nil then
            break
        end
        s = string.match(s, "^%s*(.-)%s*$")
        if s ~= "" then
            local ok, err = pcall(function()
                if not db then
                    db = assert(redis.connect { host=ip, port=port, auth=auth})
                end
                local args = {}
                for v in string.gmatch(s, "[^ ]+") do
                    table.insert(args, v)
                end
                if #args > 0 then
                    local r = db[args[1]](db, select(2, table.unpack(args)))
                    if type(r) == "table" then
                        io.stdout:write(tbl(r))
                    else
                        io.stdout:write(tostring(r))
                    end
                    io.stdout:write("\n")
                    io.stdout:flush()
                end
            end)
            if not ok then
                shaco.error(err)
                db:close()
                db = false
            end
        end
    end
    linenoise.savehistory(history_file)

    shaco.abort()
end)
