require "ptable"
require "bag"

local itemv = {
    {tpltid=1, pos=1, stack=1},
    {tpltid=2, pos=3, stack=1},
}
local bag = bag_new(1, 5, itemv)
print_table(bag, "bag")

assert(bag_item_count(bag, 1)==1)
assert(bag_item_count(bag, 2)==1)
assert(bag_add_item_bypos(bag, 8, 1, 0) == 1)
assert(bag_item_count(bag, 8)==1)
print_table(bag, "bag")

assert(bag_add_item_bypos(bag, 8, 9, 2) == 1)
assert(bag_item_count(bag, 8)==2)
print_table(bag, "bag")

assert(bag_add_item(bag, 100, 10) == 1)
assert(bag_item_count(bag, 100)==1)
print_table(bag, "bag")

assert(bag_item_enough(bag, 8, 1)==true)
assert(bag_item_enough(bag, 8, 2)==true)
assert(bag_item_enough(bag, 8, 3)==false)

assert(bag_remove_item(bag, 8, 2) == 2)
print_table(bag, "bag")

assert(bag_remove_item(bag, 100, 9) == 1)
print_table(bag, "bag")

assert(bag_space(bag) == 3)
assert(bag_remove_item_bypos(bag, 1, 1) == 1)
assert(bag_space(bag) == 4)
assert(bag_remove_item_bypos(bag, 3, 1) == 1)
assert(bag_space(bag) == 5)
print_table(bag, "bag")

assert(bag_space_enough(bag, {2000, 4994}) == true)
assert(bag_space_enough(bag, {2000, 4995}) == true)
assert(not bag_space_enough(bag, {2000, 4996}))

assert(bag_space_enough(bag, {2001, 4995}) == true)
assert(bag_space_enough(bag, {2001, 4995-999, 2000, 999}) == true)
assert(not bag_space_enough(bag, {2001, 4995-999-1, 2000, 999+1}))

assert(bag_add_item(bag, 2000, 4996)==4995)
print_table(bag, "bag")
assert(bag_add_item_bypos(bag, 2000, 1, 0) == 0)
assert(bag_remove_item(bag, 2000, 1000) == 1000)
assert(bag_remove_item(bag, 2000, 3995) == 3995)
assert(bag_remove_item(bag, 2000, 1) == 0)

assert(bag_add_item(bag, 2000, 998) == 998)
assert(bag_add_item(bag, 2001, 1) == 1)
print_table(bag, "bag")
assert(bag_add_item_bypos(bag, 2000, 1, 2) == 1)
assert(bag_add_item(bag, 2000, 1+998+999+10)==1+998+999+10)
print_table(bag, "bag")

assert(bag_add_item(bag, 2001, 1) == 1)
assert(bag_add_item(bag, 2001, 997) == 997)
assert(bag_add_item(bag, 2001, 997) == 0)
