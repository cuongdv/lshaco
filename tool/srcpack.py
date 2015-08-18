#_*_ coding:utf-8 _*_
import os
import sys

def getfile(path, exts, files):
    for f in os.listdir(path):
        f = os.path.join(path, f)
        if os.path.isfile(f):
            _, ext = os.path.splitext(os.path.basename(f))
            if ext in exts:
                files.append(f)
        else:
            getfile(f, exts, files)

def rmdirs(path):
    if os.path.isfile(path):
        os.remove(path)
    elif os.path.isdir(path):
        for f in os.listdir(path):
            f = os.path.join(path, f)
            rmdirs(f)
        os.rmdir(path)

def copydirs(path, tmp, files):
    os.mkdir(tmp)
    for f in os.listdir(path):
        if f[0] == '.': continue
        src = os.path.join(path, f)
        tar = os.path.join(tmp, f)
        if os.path.isdir(src):
            copydirs(src, tar, files)
        elif os.path.isfile(src):
            _, ext = os.path.splitext(src)
            if ext == ".lua":
                files.append(tar)
                files.append(src)
                assert(os.system("luac -o %s %s"%(tar, src)) == 0)

def srclist(path, workdir, outfile, packname):
    print ("[+]%s"%path)
    files = list()
    getfile(path, workdir, [".lua",".luac"], files, 0);
    out = open(outfile, "w");
    for f in files:
        out.write(f)
        out.write("\n")
    out.close()
    print "[=]%s"%outfile

if __name__ == "__main__":
    if len(sys.argv) < 4:
        print "usage : %s path outdir workdir" % sys.argv[0]
        sys.exit(1)

    path = sys.argv[1].strip('/').strip('\\')
    packname = os.path.basename(path)
    outdir = sys.argv[2]
    workdir = sys.argv[3]
    slfile = "./%s.sl"%packname

    tmpdir = "__tmp_srcpack_"+packname
    if os.path.isdir(tmpdir):
        rmdirs(tmpdir)

    files = list()
    copydirs(path, tmpdir, files)
    print ("[+]%s"%path)
    out = open(slfile, "w");
    for f in files:
        out.write(f)
        out.write("\n")
    out.close()
    print "[=]%s"%slfile

    lsofile = os.path.join(outdir, packname+".lso")
    assert (os.system("./srcpack pack %s %s"%(lsofile, slfile)) == 0)

    rmdirs(tmpdir)
