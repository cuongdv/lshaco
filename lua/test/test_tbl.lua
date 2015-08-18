local shaco = require "shaco"
local sfmt = string.format
local tbl = require "tbl"

local a = { {1,2,3},}

a.a = { 

	hello = { 
	},
	world =  {
		foo = "ooxx",
		bar = "haha",
		root = a,
	},
}
a.b = { 
	test = a[1],
    test2=a.a
}

tbl.print(a, "a", shaco.trace)

local function role_info_gen()
	return {
		mapid = 0,
		posx = 0,
		posy = 0,
		coin = 0,
		gold = 0,
		package_size = 0,
        exp = 0,
        refresh_time = 0,
        oid = 0,
        open_ectype = {}
	}
end

local info = role_info_gen()
tbl.print(info, "info", shaco.trace)
--print(tbl.serialize(a, "a"))
--print(tbl.serialize_s(a, "a"))
--
