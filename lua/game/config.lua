local shaco = require "shaco"

local config = {
    open_server_time = nil
}

function config.init()
    local f = io.open(".time.tmp", "a+")
    local s = f:read("*a")
    local n = tonumber(s)
    if not n then
        n = os.time() 
        f:write(tostring(n))
    end
    config.open_server_time = n
    shaco.info("config.open_server_time =", config.open_server_time)
    f:close()
end

return config
