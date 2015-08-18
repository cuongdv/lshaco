#_*_ coding:utf-8 _*_

import os
import sys

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print "usage : %s path outfile" % sys.argv[0]
        sys.exit(1)

    path = sys.argv[1]
    outfile = sys.argv[2]
    outname = os.path.basename(outfile)

    print "[Collect all tplt ...]"
   
    lines = list()
    files = os.listdir(path)
    for fname in files:
        if outname != fname:
            cname, _ = os.path.splitext(fname)
            if cname[:2] == "__":
                lines.append(cname[4:])
    out = open(outfile, "w");
    out.write('return "%s"'%(",".join(lines)))
    print "[=]%s"%outfile 
