local LUA_SERVICE = "./lua/?.lua;;aa;aa/bb/cc/?.lua"
local msg = {}
local main
for pat in string.gmatch(LUA_SERVICE, '([^;]+);*') do
    local f, err = loadfile(string.gsub(pat, '?', "game"))
    if not f then
        table.insert(msg, err)
    else
        main = f
        break
    end
end

if not main then
    error(table.concat(msg, '\n'))
end
main()
