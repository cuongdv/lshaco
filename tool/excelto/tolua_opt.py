#_*_coding:utf-8_*_

##
# @file tolua_opt.py
# @brief    excel数据转化为lua数据
# @author lvxiaojun
# @version 
# @Copyright shengjoy.com
# @date 2012-12-19

import os
from exparser import *
from exconvertor import *

__all__ = []

_optname = u"lua"

class seri_opt:
    def seri(self, excels, infile, name, table, field_map):
        """
        序列化所有数据
        """
        self.excels = excels
        self.infile = infile
        self.name = name
        self.load_extern(field_map)
        if table.haskey():
            return self._seri_by_key(name, table, field_map)
        else:
            return self._seri_normal(name, table, field_map)
    
    def load_extern(self, self_map):
        self.extern_t = dict()
        for i in range(len(self_map)):
            extern = field_map_get_is_extern(self_map, i)
            if extern:
                sheetdesc = self.excels[extern[0]][extern[1]]
                fields = sheetdesc["fields"]
                field_map = ep_filter_fields(fields, u"lua")
                sheetname = sheetdesc["name"]
                outname = sheetdesc["outfile"]
                infile = os.path.join(os.path.dirname(self.infile), extern[0])
                sheet = ep_open(infile, sheetname)
                table = ep_parse(sheet, field_map)
                data = table.restruct() 
                self.extern_t[i] = (table, data, field_map)
                 
    def _seri_normal(self, name, table, field_map):
        items = table.items
        r = []
        for i in range(len(items)):
            v = self._seri_item(items[i], field_map, -1)
            r.append(v)
        return "local %s={\n%s\n}\nreturn %s" % (name, ",\n".join(r), name)

    def _find_key(self, name, table, data, field_map, key):
        
        group = data[key]
        g = []
        if table.unique:
            if len(group) != 1:
                log.write("table %s has duplicate key\n"%name)
                exit(1)
        for item in group:
            v = self._seri_item(item, field_map, table.keycol)
            g.append(v)
        
        val = ",\n".join(g)
        if table.unique:
            return val
        else:
            return ("{\n%s\n}" % (",\n".join(g)))

    def _seri_by_key(self, name, table, field_map):
        data = table.restruct()
        r = []
        for key in sorted(data.keys()):
            keytype = field_map_get_ftype(field_map, table.keycol)
            keyv = self._seri_key(key, keytype, "<key>", "<key>")
            value = self._find_key(name, table, data, field_map, key)
            r.append("%s=%s"%(keyv, value))
        return "local %s={\n%s\n}\nreturn %s" % (name, ",\n".join(r), name)

    def _seri_item(self, item, field_map, keycol):
        """
        序列化单行数据
        """
        r = []
        for i in range(len(item)):
            #if i == keycol: continue
            fname = field_map_get_fname(field_map, i)
            fvname = field_map_get_fvname(field_map, i)
            ftype = field_map_get_ftype(field_map, i)
            isarray = field_map_get_is_array(field_map, i)
            extern = field_map_get_is_extern(field_map, i)
            v = self._seri_value(i, item[i], ftype, fname, fvname, isarray, extern) 
            f = "%s=%s"%(fvname, v)
            r.append(f)
        return "{%s}" % ",".join(r)

    def _seri_value(self, i, v, ftype, fname, fvname, isarray, extern):
        if extern:
            extern_d = self.extern_t[i]
            return self._find_key(self.name, extern_d[0], extern_d[1], extern_d[2], v)
        if isarray:
            v = unicode(v).strip().rstrip(';')
            subv = v.split(';')
        if ftype == "string":
            v = unicode(v).replace("\n", "")
            return '"%s"'%unicode(v)
        elif ftype == "float":
            if isarray: return '{%s}'%(','.join(map(lambda x:float(x), subv)))
            else:       return float(v) if v else 0.0
        elif ftype == "int32_t" or ftype == "uint32_t":
            if isarray: return '{%s}'%(','.join(map(lambda x:long(x), subv)))
            else:       return long(v) if v else 0
        elif ftype == "intw":
            if isarray: 
                subv = map(lambda x: '{%s}'%(','.join(x.split(':'))), subv)
                return '{%s}'%','.join(subv)
            else:       
                subv = map(lambda x:unicode(long(x)), unicode(v).split(':'))[:2]
                return '{%s}'%','.join(subv)
        elif ftype == "intt":
            if isarray: 
                subv = map(lambda x: '{%s}'%(','.join(x.split(':'))), subv)
                return '{%s}'%','.join(subv)
            else:
                subv = map(lambda x:unicode(x), unicode(v).split(':'))[:3]
                return '{%s}'%','.join(subv)
        else:
            log.write("\n[error : unknow field type, "
                    "name#%s, vname#%s, type#%s, val#%s]\n"%
                    (fname, fvname, ftype, v))

    def _seri_key(self, v, ftype, fname, fvname):
        return "[%s]" % self._seri_value(0, v, ftype, fname, fvname, False, False)

_optname2 = u"lua2"

class seri_opt2(seri_opt):
    def _seri_field(self, fvname, v):
        return v

def _dump_to_file(outfile, s):
    """
    输出到文件
    """
    op = file(outfile, "wb")
    op.write(s)
    op.close()

def _convert(excels, infile, sheetdesc, out_dir, optname, seri):
    """
    执行转化
    """
    fields = sheetdesc["fields"]
    field_map = ep_filter_fields(fields, optname)
    if len(field_map) == 0: return CONV_NO_FIELDS
  
    sheetname = sheetdesc["name"]
    outname = sheetdesc["outfile"]
    if outname[:4] != "tp":
        outname = "tp" + outname 

    outfile = os.path.join(out_dir, "__%s.%s"%(outname.lower(), _optname))
    sheet = ep_open(infile, sheetname)
    table = ep_parse(sheet, field_map)
    s = seri.seri(excels, infile, outname.upper(), table, field_map)
    _dump_to_file(outfile, s)
    log.write(outfile)
    return CONV_OK

def _convert1(infile, sheetdesc, out_dir, excels):
    return _convert(excels, infile, sheetdesc, out_dir, _optname, seri_opt())

def _convert2(infile, sheetdesc, out_dir):
    return _convert(excels, infile, sheetdesc, out_dir, _optname2, seri_opt2())


#安装本引擎
ec_install_opt(_optname, _convert1)
ec_install_opt(_optname2, _convert2)
