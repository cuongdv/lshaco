local args = {}
for w in string.gmatch(..., '%S+') do
    table.insert(args, w)
end

local mod = args[1]
assert(mod, "Lua mod is nil")

local main
local errv = {}
for pat in string.gmatch(LUA_MODPATH, '([^;]+);*') do
    local filename = string.gsub(pat, '?', mod)
    local block, err = loadfile(filename)
    if not block then
        table.insert(errv, err)
    else
        main = block 
        break
    end
end
if not main then
    error(table.concat(errv, '\n'))
end

setmetatable(_ENV, {
__index = function(_, k) 
    error('Attempt to read undeclared var `'..k..'`', 2)
end,
__newindex = function(_, k)
    error('Attempt to write undeclared var `'..k..'`', 2)
end,
})

package.path  = LUA_PATH--..';'..package.path
package.cpath = LUA_CPATH--..';'..package.cpath

main(select(2, table.unpack(args)))
