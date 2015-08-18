#_*_coding:utf-8_*_

##
# @file tolua_opt.py
# @brief    excel数据转化为tbl数据
# @author lvxiaojun
# @version 
# @Copyright shengjoy.com
# @date 2012-12-19

import struct
import os 
from exparser import *
from exconvertor import *

__all__ = []

_optname = u"tbl"

def _serialize_to_file(table, field_map, outfile):
    """
    序列化所有数据
    """
    items = table.items
    op = file(outfile, "wb")
    op.write(struct.pack("I", len(items)))
    rowlen = 0
    for i in range(field_map_size(field_map)):
        flen = field_map_get_flen(field_map, i)
        ftype = field_map_get_ftype(field_map, i)
        is_selfdefine = field_map_get_is_selfdefine(field_map, i)
        is_array = field_map_get_is_array(field_map, i)
        arraysz = field_map_get_arraysz(field_map, i)
        if is_selfdefine == 1:
            flen = 8
        elif is_selfdefine > 1:
            flen = 2+8
        elif is_array:
            flen = 2 + flen* arraysz
        rowlen += flen

    op.write(struct.pack("I", rowlen))
    for row in range(len(items)):
        item = items[row]
        for i in range(len(item)):
            val = item[i]
            fname = field_map_get_fname(field_map, i)
            fvname = field_map_get_fvname(field_map, i)
            flen = field_map_get_flen(field_map, i)
            ftype = field_map_get_ftype(field_map, i)
            is_selfdefine = field_map_get_is_selfdefine(field_map, i)
            is_array = field_map_get_is_array(field_map, i) 
            arraysz = field_map_get_arraysz(field_map, i)
            try:
                if is_selfdefine == 1:
                    op.write(struct.pack("Q", 0))
                elif is_selfdefine > 1:
                    op.write(struct.pack("H", 0))
                    op.write(struct.pack("Q", 0))
                else:
                    subv = []
                    if is_array:
                        val = str(val).strip()
                        if val:
                            val = val.rstrip(',')
                            subv = map(lambda x: x, val.split(","))
                        if len(subv) > arraysz:
                            log.write("\n[error : field len too small, real is %d, "
                                    "name#%s, vname#%s, type#%s, len#%s val#%s]\n"%
                            (len(subv), fname, fvname, ftype, flen, val))
                            exit(1)
                        op.write(struct.pack("H", len(subv)))
                    else:
                        subv = [val]
                    nsub = len(subv)
                    for vi in range(arraysz):
                        v = vi < nsub and subv[vi] or 0 
                        if (ftype == "int32_t" or ftype == "uint32_t"):
                            op.write(struct.pack("i", v and int(float(v)) or 0))
                        elif (ftype == "uint64_t" or ftype == "int64_t"):
                            op.write(struct.pack("Q", v and long(v) or 0))
                        elif (ftype == "float"):
                            op.write(struct.pack("f", v and float(v) or 0))
                        elif ftype == "string":
                            op.write(struct.pack("%ds" % (flen-1), str(v)))
                            op.write(struct.pack("c", '\0'))
                        elif ftype == "idnum":
                            iv = map(lambda x: x, val.split(':'))
                            if len(iv) != 2:
                                log.write("\n[error : field must `id:num`, "
                                        "name#%s, vname#%s, type#%s, len#%s val#%s]\n"%
                                        (fname, fvname, ftype, flen, val))
                                exit(1)
                            op.write(struct.pack("I", v and int(float(iv[0])) or 0))
                            op.write(struct.pack("I", v and int(float(iv[1])) or 0))
                        elif ftype == "idnumrate":
                            iv = map(lambda x: x, val.split(':'))
                            if len(iv) != 3:
                                log.write("\n[error : field must `id:num:rate`, "
                                        "name#%s, vname#%s, type#%s, len#%s val#%s]\n"%
                                        (fname, fvname, ftype, flen, val))
                                exit(1)
                            op.write(struct.pack("I", v and int(float(iv[0])) or 0))
                            op.write(struct.pack("I", v and int(float(iv[1])) or 0))
                            op.write(struct.pack("I", v and int(float(iv[2])) or 0))
                        elif ftype == "vec3d":
                            iv = map(lambda x: x, val.split(':'))
                            if len(iv) != 3:
                                log.write("\n[error : field must `x:y:z`, "
                                        "name#%s, vname#%s, type#%s, len#%s val#%s]\n"%
                                        (fname, fvname, ftype, flen, val))
                                exit(1)
                            op.write(struct.pack("f", v and float(iv[0]) or 0))
                            op.write(struct.pack("f", v and float(iv[1]) or 0))
                            op.write(struct.pack("f", v and float(iv[2]) or 0))
                        else:
                            log.write("\n[error : unknow field type, "
                            "name#%s, vname#%s, type#%s, len#%s, val#%s, is_array#%d, arraysz#%d]\n"%
                            (fname, fvname, ftype, flen, val, is_array, arraysz))
                            exit(1)
            except Exception, e:
                log.write(str(e))
                log.write("\n[exception: unknow field type, "
                          "#name#%s, vname#%s, type#%s, len#%s val#%s, is_array#%d, arraysz#%d]\n"%
                           (fname, fvname, ftype, flen, val, is_array, arraysz))
                exit(1)
    op.close() 

def _convert(infile, sheetdesc, out_dir):
    """
    执行转化
    """
    fields    = sheetdesc["fields"]
    field_map = ep_filter_fields(fields, _optname)
    if len(field_map) == 0: return CONV_NO_FIELDS

    sheetname = sheetdesc["name"]
    outfile   = sheetdesc["outfile"]
    outfile   = os.path.join(out_dir, "%s.%s"%(outfile, _optname))
    sheet     = ep_open(infile, sheetname)
    table     = ep_parse(sheet, field_map)
    _serialize_to_file(table, field_map, outfile)
    log.write(outfile)
    return CONV_OK

#安装本引擎
ec_install_opt(_optname, _convert)
