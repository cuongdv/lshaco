#_*_coding:utf-8_*_

import struct
import os

from exparser import *
from exconvertor import *

__all__ = []

_optname = u"formula"

def replace(s, replace_l):
    idx_l = list()
    replace_l.sort(lambda x,y: len(y[0])-len(x[0]))
    i = 0
    while i < len(s):
        found = False
        for j in range(len(s), i, -1):
            for fr, to in replace_l:
                if s[i:j] == fr:
                    idx_l.append([i,j,to])
                    found = True
                    break
            if found:
                break
        i = found and j or i+1
    off = 0
    for i, j, to in idx_l:
        i = i + off
        j = j + off
        off = off + len(to)-(j-i)
        s = s[:i] + to + s[j:]
    return s
   
def open_formula(excel, sheetname):
    sheet = ep_opensheet(excel, sheetname)
    table = ep_parse_raw(sheet)
    items = table.items
    l = []
    for i in range(1, len(items)):
        name = items[i][0].strip()
        formula = items[i][1].strip()
        if name and formula:
            l.append((name, formula))
    return l 

def open_para(excel, sheetname, desc):
    sheet = ep_opensheet(excel, sheetname) 
    table = ep_parse_raw(sheet)
    items = table.items
    row = len(items)
    field_idx = 1
    desc_idx = 2
    l = []
    for i in range(1, len(items)):
        if items[i][desc_idx] == desc:
            v = items[i][field_idx]
            if v not in l:
                l.append(v)
    return l 

def seri_function(name, formula):
    return u"""
function formula.get_%s(me, ot, me_tp, ot_tp)
    return %s
end"""%(name, formula)

def _convert(infile, sheetdesc, out_dir, excels):
    """
    执行转化
    """
    fields    = sheetdesc["fields"]
    field_map = ep_filter_fields(fields, _optname)
    if len(field_map) == 0: return CONV_NO_FIELDS

    sheetname = sheetdesc["name"]
    outfile   = sheetdesc["outfile"]
    outfile   = os.path.join(out_dir, "%s.lua"%(outfile))

    excel = ep_openexcel(infile)
    formula_l = open_formula(excel, u"公式")
    paravar = open_para(excel, u"公式参数", u"玩家属性")
    parafix = open_para(excel, u"公式参数", u"表填值")

    para_l = []
    for x in parafix:
        me = u"S%s"%x
        ot = u"T%s"%x
        para_l.append((me, u"me_tp.%s"%x))
        para_l.append((ot, u"ot_tp.%s"%x))
    for x in paravar:
        me = u"S%s"%x
        ot = u"T%s"%x
        para_l.append((me, u"me:get_%s()"%x))
        para_l.append((ot, u"ot:get_%s()"%x))
    para_l.sort(lambda x,y:len(y[0])-len(x[0]))

    funs = []
    for name, formula in formula_l:
        funs.append(seri_function(name, replace(formula, para_l)))
    content = u"""\
local RANDBETWEEN = math.random
local min = math.min
local max = math.max
local ROUNDDOWN = math.floor
local ROUNDUP = math.ceil
local ROUND = function(x) ROUNDDOWN(x+0.5) end

local formula = {}
%s
return formula"""%("\n".join(funs))
    #log.write(content)
    fp = file(outfile, "wb")
    fp.write(content)
    fp.close()
    log.write(outfile)
    return CONV_OK

#安装本引擎
ec_install_opt(_optname, _convert)
