local tostring = tostring
local type = type
local pairs = pairs
local srep = string.rep
local tinsert = table.insert
local tconcat = table.concat
local sformat = string.format
local sgsub = string.gsub

local tbl = {}

local function key(k)
    if type(k) == "number" then
        return "["..k.."]"
    else
        return tostring(k)
    end
end

local function value(v)
    if type(v) == "string" then
        v = sgsub(v, '"', '\\"')
        return '"'..v..'"'
    else
        return tostring(v)
    end
end

local function fullkey(ns, k)
    if type(k) == "number" then
        return ns.."["..k.."]"
    else
        return ns.."."..tostring(k)
    end
end

return function (t, name)
    if type(name) ~= 'string' then
        name = tostring(t)
    end
    local cache = { [t] = name }
	local function serialize(t, name, tab, ns)
        local tab2 = tab.."  "
        local fields = {}
		for k, v in pairs(t) do
			if cache[v] then
                tinsert(fields, key(k).."="..cache[v])
			else
                if type(v) == "table" then
                    local fk = fullkey(ns, k)
				    cache[v] = fk
				    tinsert(fields, serialize(v, k, tab2, fk))
                else
                    tinsert(fields, key(k).."="..value(v))
                end
			end
		end	
        return key(name).."={\n"..tab2..
            tconcat(fields, ",\n"..tab2).."\n"..tab.."}"
	end	
	return serialize(t, name, "", name)
end
