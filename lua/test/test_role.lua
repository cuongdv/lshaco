local tprole = require "__tprole"
local tbl = require "tbl"

local pt = { base={level=1,race=10}, info={exp=0}}
function pt:addexp(got)
    local base = self.base
    local info = self.info
    local index = base.race * 1000 + base.level
    info.exp = info.exp + got
    while true do
        local tp = tprole[index]
        print(tp, index)
        if tp then
            if info.exp >= tp.exp then 
                base.level = base.level+1
                info.exp = info.exp - tp.exp
                --ur:db_tagdirty(self.DB_ROLE)
            else
                break
            end
        else
            break
        end
    end
end

pt.base.level = 1
pt.info.exp = 0


pt:addexp(100)
tbl.print(pt, "pt")
assert(pt.base.level==2 and pt.info.exp==0)

pt:addexp(100)
tbl.print(pt, "pt")
assert(pt.base.level==2 and pt.info.exp==100)

pt:addexp(650)
tbl.print(pt, "pt")
assert(pt.base.level==3 and pt.info.exp==150)

pt:addexp(950)
tbl.print(pt, "pt")
assert(pt.base.level==4 and pt.info.exp==0)

pt:addexp(9500)
tbl.print(pt, "pt")
assert(pt.base.level==4 and pt.info.exp==9500)
