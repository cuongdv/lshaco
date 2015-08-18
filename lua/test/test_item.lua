local shaco = require "shaco"
local tbl = require "tbl"
local bag = require "bag"

local itemv = {
    {tpltid=1, pos=1, stack=1},
    {tpltid=2, pos=3, stack=1},
}
local pkg = bag.new(1, 5, itemv)
tbl.print(pkg, "pkg", shaco.trace)

assert(pkg:count(1)==1)
assert(pkg:count(2)==1)
assert(pkg:put_bypos(8, 1, 0) == 1)
assert(pkg:count(8)==1)
tbl.print(pkg, "pkg", shaco.trace)

assert(pkg:put_bypos(8, 9, 2) == 1)
assert(pkg:count(8)==2)
tbl.print(pkg, "pkg", shaco.trace)

assert(pkg:put(100, 10) == 1)
assert(pkg:count(100)==1)
tbl.print(pkg, "pkg", shaco.trace)

assert(pkg:enough(8, 1)==true)
assert(pkg:enough(8, 2)==true)
assert(pkg:enough(8, 3)==false)

assert(pkg:remove(8, 2) == 2)
tbl.print(pkg, "pkg", shaco.trace)

assert(pkg:remove(100, 9) == 1)
tbl.print(pkg, "pkg", shaco.trace)

assert(pkg:space(pkg) == 3)
assert(pkg:remove_bypos(1, 1) == 1)
assert(pkg:space(pkg) == 4)
assert(pkg:remove_bypos(3, 1) == 1)
assert(pkg:space(pkg) == 5)
tbl.print(pkg, "pkg", shaco.trace)

assert(pkg:space_enough({{2000, 4994}}) == true)
assert(pkg:space_enough({{2000, 4995}}) == true)
assert(not pkg:space_enough({{2000, 4996}}))

assert(pkg:space_enough({{2001, 4995}}) == true)
assert(pkg:space_enough({{2001, 4995-999}, {2000, 999}}) == true)
assert(not pkg:space_enough({{2001, 4995-999-1}, {2000, 999+1}}))

assert(pkg:put(2000, 4996)==4995)
tbl.print(pkg, "pkg", shaco.trace)
assert(pkg:put_bypos(2000, 1, 0) == 0)
assert(pkg:remove(2000, 1000) == 1000)
assert(pkg:remove(2000, 3995) == 3995)
assert(pkg:remove(2000, 1) == 0)

assert(pkg:put(2000, 998) == 998)
assert(pkg:put(2001, 1) == 1)
tbl.print(pkg, "pkg", shaco.trace)
assert(pkg:put_bypos(2000, 1, 2) == 1)
assert(pkg:put(2000, 1+998+999+10)==1+998+999+10)
tbl.print(pkg, "pkg", shaco.trace)

assert(pkg:put(2001, 1) == 1)
assert(pkg:put(2001, 997) == 997)
assert(pkg:put(2001, 997) == 0)
