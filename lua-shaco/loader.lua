local mod, _ = ...
assert(mod, "lua mod is nil")
package.path = package.path .. ';' .. LUA_PATH
package.cpath = package.cpath .. ';' .. LUA_CPATH
package.packpath = LUA_PACKPATH
local main
local msg = {}
for pat in string.gmatch(LUA_MODPATH, '([^;]+);*') do
    local filename = string.gsub(pat, '?', mod)
    local f, err = loadfile(filename)
    if not f then
        table.insert(msg, err)
    else
        main = f
        break
    end
end
if not main then
    if #msg > 0 then error(table.concat(msg, '\n'))
    else error("no found lua file")
    end
end
setmetatable(_ENV, {
__index = function(_, k) 
    error('attempt to read undeclared var `'..k..'`', 2)
end,
__newindex = function(_, k)
    error('attempt to write undeclared var `'..k..'`', 2)
end,
})
main()
