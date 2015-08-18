#_*_coding:utf-8_*_

##
# @file toc_opt.py
# @brief    excel数据转化为c数据
# @author lvxiaojun
# @version 
# @Copyright shengjoy.com
# @date 2012-12-19

import struct
import os 
from exparser import *
from exconvertor import *

__all__ = []

_optname = u"c"

def _serialize_to_file(cname, sheetname, field_map, outfile):
    """
    序列化所有数据
    """
    op = file(outfile, "wb")
    op.write("// %s\n"%sheetname)
    op.write("struct %s_tplt {\n"%cname)
    for i in range(field_map_size(field_map)):
        fname = field_map_get_fname(field_map, i)
        fvname = field_map_get_fvname(field_map, i)
        flen   = field_map_get_flen(field_map, i)
        ftype  = field_map_get_ftype(field_map, i)
        is_selfdefine = field_map_get_is_selfdefine(field_map, i)
        is_array = field_map_get_is_array(field_map, i)
        arraysz = field_map_get_arraysz(field_map, i)

        if is_selfdefine == 1:
            fstr1 = ""
            fstr2 = ""
        elif is_selfdefine > 1:
            fstr1 = "uint16_t n%s;\n    "%fvname
            fstr2 = ""
        elif is_array:
            fstr1 = "uint16_t n%s;\n    "%fvname
            fstr2 = "[%d]"%arraysz
        else:
            fstr1 = ""
            fstr2 = ""
        if is_selfdefine == 2:
            fstr = "%s *%s"%(ftype, fvname)
        elif is_selfdefine == 3 or is_selfdefine == 1:
            fstr = "const struct %s *%s"%(ftype, fvname)
        elif (ftype == "uint32_t" or ftype == "int32_t"):
            fstr = "%s %s"%(ftype, fvname)
        elif (ftype == "uint64_t" or ftype == "int64_t"):
            fstr = "%s %s"%(ftype, fvname)
        elif (ftype == "float"):
            fstr = "%s %s"%(ftype, fvname)
        elif ftype == "string":
            fstr = "char %s[%d]"%(fvname, flen)
        elif ftype == "idnum":
            fstr = "struct idnum %s"%(fvname)
        elif ftype == "idnumrate":
            fstr = "struct idnumrate %s"%(fvname)
        elif ftype == "vec3d":
            fstr = "struct vec3d %s"%(fvname)
        else:
            log.write("\n[error : unknow field type, \
            name#%s, vname#%s, type#%s, len#%s, is_array#%d, arrraysz#%d]\n"%
            (fname, fvname, ftype, flen, is_array, arraysz))
            exit(1)
        fstr = "%s%s%s"%(fstr1, fstr, fstr2)
        op.write("    %s; %s %s\n"%(fstr, "//".rjust(25-len(fstr)), fname))
    op.write("\n};");
    op.close() 

def _convert(infile, sheetdesc, out_dir):
    """
    执行转化
    """
    fields    = sheetdesc["fields"]
    field_map = ep_filter_fields(fields, _optname)
    if len(field_map) == 0: return CONV_NO_FIELDS

    sheetname = sheetdesc["name"]
    cname     = sheetdesc["outfile"]
    outfile   = sheetdesc["outfile"]
    outfile   = os.path.join(out_dir, "%s.%s"%(outfile, _optname))
    _serialize_to_file(cname, sheetname, field_map, outfile)
    log.write(outfile)
    return CONV_OK

#安装本引擎
ec_install_opt(_optname, _convert)
