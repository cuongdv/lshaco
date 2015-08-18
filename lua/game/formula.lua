local RANDBETWEEN = math.random
local min = math.min
local max = math.max
local ROUNDDOWN = math.floor
local ROUNDUP = math.ceil
local ROUND = function(x) ROUNDDOWN(x+0.5) end

local formula = {}

function formula.get_AtkHurt(me, ot, me_tp, ot_tp)
    return max(me:get_Atk()*3*(me_tp.AtkPer/10000)-ot:get_Def()*3+me:get_Atk()*RANDBETWEEN(1,10)*0.01+me_tp.AtkFixed,10)
end

function formula.get_MagicHurt(me, ot, me_tp, ot_tp)
    return max(me:get_Mag()*3.1*(me_tp.MagPer/10000)-ot:get_MagDef()*3.1+me:get_Mag()*RANDBETWEEN(1,5)*0.01+me_tp.MagFixed,0)
end

function formula.get_AtkCrit(me, ot, me_tp, ot_tp)
    return min((me:get_AtkCrit()+me_tp.AtkCritFix*2)/(me:get_AtkCrit()+ot:get_AtkRes()*3+100),0.6)
end

function formula.get_MagicCrit(me, ot, me_tp, ot_tp)
    return min((me:get_MagCrit()+me_tp.MagCritFix*2)/(me:get_MagCrit()+ot:get_MagCrit()*3+100),0.6)
end

function formula.get_HitsFormula(me, ot, me_tp, ot_tp)
    return min((me:get_Hits()+me_tp.HitsFix+ot:get_Block()*3)/(ot:get_Block()*4),1)
end

function formula.get_HPReplyFormula(me, ot, me_tp, ot_tp)
    return 100*me:get_HPReply()*0.01
end

function formula.get_BUFFHurt(me, ot, me_tp, ot_tp)
    return me_tp.BUFFFix+me:get_Atk()*(me_tp.AtkPer/100)+me:get_Mag()*(me_tp.MagPer/100)
end

function formula.get_Combat(me, ot, me_tp, ot_tp)
    return me:get_Atk()/10+me:get_Mag()/10+me:get_Def()/10+me:get_MagDef()/10+me:get_HP()/100+me:get_MP()+me:get_AtkCrit()/10+me:get_MagCrit()/10+me:get_AtkRes()/10+me:get_MagRes()/10+me:get_Block()/10+me:get_Dodge()/10+me:get_MPReply()/10+me:get_Hits()/10+me:get_HPReply()/10
end

function formula.get_DropGold(me, ot, me_tp, ot_tp)
    return (Gold_Drop/Gold_Number)/MAX((Monster_Number*RAND()),3)
end

function formula.get_Guaranteeing(me, ot, me_tp, ot_tp)
    return (SXHP/max(TMAtk+TMMag-SXDef-SXMagDef,1)*1.5)/(TMHP/max(SXAtk+SXMag-TMDef-TMMagDef,1))
end
return formula