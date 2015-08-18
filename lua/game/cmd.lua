local shaco = require "shaco"
local hotfix = require "hotfix"
local REQ = require "req"
local string = string
local table = table

local CMD = {}

CMD.hotfix = function(names)
    if names == nil then
        return "no argument"
    end
    for name in string.gmatch(names, "[%w_.]+") do
        local t = {}
        for w in string.gmatch(name, "[%w_]+") do
            table.insert(t, w)
        end
        if #t == 1 then
            table.insert(t, 1, "game")
        end
        local name = t[#t]
        local patch = string.format("../lua/%s.lua", table.concat(t, "/")) 
        hotfix(name, patch, "U")
        if string.sub(name, 1, 2) == "h_" then
            REQ.__REG { name }
        end
    end
end

CMD.reloadres = function(names)
    if names == nil then
        return "no argument"
    end
    local t = {}
    for name in string.gmatch(names, "[%w_]+") do
        local name = string.format("__tp%s", name)
        local patch = string.format("../res/lua/%s.lua", name)
        local ok, err = pcall(hotfix, name, patch, "R")
        if not ok then
            table.insert(t, err)
        end
    end
    return table.concat(t, "\n")
end

CMD.reloadresall = function()
    local f, err = loadfile("../res/lua/__alltplt.lua")
    if not f then
        return err
    else
        return CMD.reloadres(f())
    end 
end

return CMD
