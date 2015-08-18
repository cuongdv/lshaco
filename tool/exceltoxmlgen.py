#_*_ coding:utf-8 _*_

##
# @file 
# @brief    excel生成excelto.xml
# @author lvxiaojun
# @version 
# @Copyright shengjoy.com
# @date 2012-12-19

import os
import sys
import xlrd

reload(sys)
sys.setdefaultencoding("utf-8")
log = sys.stdout

def ep_opensheet(excelname, sheetname):
    try:
        excel = xlrd.open_workbook(excelname)
        if sheetname:
            excel = ep_openexcel(excelname)
        else:
            sheet = excel.sheets()[0]
    except Exception, e:
        log.write("[error : %s]\n"%str(e))
        exit(1)
    return sheet

def getfile(path, exts):
    files = []
    for f in os.listdir(path):
        f = os.path.join(path, f)
        if os.path.isfile(f):
            _, ext = os.path.splitext(os.path.basename(f))
            if ext in exts:
                files.append(f)
    return files

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print "usage : %s excel_dir excelto.xml" % sys.argv[0]
        sys.exit(1)

    excel_dir = sys.argv[1]
    to_file = sys.argv[2]

    to = file(to_file, "wb")
    to.write('<?xml version="1.0" encoding="utf-8"?>\n')
    to.write('<database>\n')
    excel_files = getfile(excel_dir, (".xlsx", ".xls"))
    for excelname in excel_files:
        log.write("-> %s\n"%excelname)
        sheet = ep_opensheet(excelname, "")
        basename = os.path.basename(excelname)
        toname, _= os.path.splitext(basename)
        namel = sheet.row_values(0)
        vamel = sheet.row_values(1)
        assert(len(namel) == len(vamel))

        to.write('\t<table name="%s" number="1">\n'%basename)
        to.write('\t\t<SHEET filename="%s" name="%s" number="1" to="lua">\n'%(basename, sheet.name))
        for i in range(len(namel)):
            name = namel[i]
            vame = vamel[i]
            to.write('\t\t\t<FIELD name="%s" vname="%s" type="" len="0" to="lua"/>\n'%(name, vame))
        to.write('\t\t</SHEET>\n')
        to.write('\t</table>\n')
    to.write('</database>\n')
    to.close()
