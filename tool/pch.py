#_*_ coding:utf-8 _*_

import os

def getfile(path, exts, files, level):
    #if level > 10:
        #return

    for f in os.listdir(path):
        f = os.path.join(path, f)
        if os.path.isfile(f):
            _, ext = os.path.splitext(os.path.basename(f))
            if ext in exts:
                files.append(f)
        else:
            getfile(f, exts, files, level+1)

if __name__ == "__main__":
    files = []
    getfile(".", (".cpp"), files, 0)

    for fname in files:
        print (fname)
        fp = file(fname, "r+")
        c = fp.read()
        #print (c)
        fp.seek(0)
        fp.write('#include "stdafx.h"\n')
        fp.write(c)
        fp.close()
