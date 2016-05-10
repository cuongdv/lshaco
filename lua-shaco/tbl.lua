local function tbl(t, name)
    local tostring = tostring
    local type = type
    local pairs = pairs
    local tinsert = table.insert
    local tconcat = table.concat
    local sformat = string.format
    local sgsub = string.gsub

    local function key(k)           return type(k)=="number" and "["..k.."]" or tostring(k) end
    local function value(v)         return type(v)=="string" and '"'..sgsub(v,'"','\\"')..'"' or tostring(v) end
    local function fullkey(ns, k)   return ns..(type(k)=="number" and "["..k.."]" or "."..tostring(k)) end
   
    name = tostring(name)
    
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
        return sformat("%s={\n%s%s\n%s}", key(name), tab2, tconcat(fields, ",\n"..tab2), tab)
	end	
	return serialize(t, name, "", name)
end
return tbl
