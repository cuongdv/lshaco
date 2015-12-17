local tbl = require "tbl"

local t = { }
t[1] = 10
t.a = '123'
t[2] = t
print(tbl(t, 'name'))
