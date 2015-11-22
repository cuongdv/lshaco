local shaco = require "shaco"
local cmdcall = require "cmdcall"
local table = table
local string = string
local math = math
local os = os
local pairs = pairs
local type = type

local CMD = {}

CMD.help = function()
    local t = {""}
    for k, v in pairs(CMD) do
        if type(v) == "function" then
            table.insert(t, k)
        end
    end
    return table.concat(t, "\n____ ")
end

CMD.getloglevel = function()
    return shaco.getloglevel()
end

CMD.setloglevel = function(level)
    if level == nil then
        return "no argument"
    end
    return shaco.setloglevel(level)
end

CMD.time = function()
    local start = shaco.starttime()//1000
    local now = shaco.now()//1000
    local dif = now-start
    local h = dif//3600; dif = dif%3600
    local m = dif//60;   dif = dif%60
    local s = dif
    return os.date("%y/%m/%d-%H:%M:%S", start).." ~ "..
           os.date("%y/%m/%d-%H:%M:%S", now)..
           string.format("[%dh%dm%ds]", h,m,s)
end

CMD.gc = function()
    local m1 = collectgarbage("count")
    collectgarbage("collect")
    local m2 = collectgarbage("count")
    return string.format("%f <- %f", m2, m1)
end

shaco.start(function()
    shaco.publish("cmdctl")
    shaco.subscribe("cmds")
    
    shaco.dispatch("um", function(session, source, id, s)
        return cmdcall(CMD, source, id, s)
    end)
end)
