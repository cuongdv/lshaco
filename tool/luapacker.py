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

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print "usage : %s path(.lua) outdir(.lso)" % sys.argv[0]
        sys.exit(1)
    toolpath = os.path.dirname(sys.argv[0])
    path = sys.argv[1].strip('/').strip('\\')
    packname = os.path.basename(path)
    outdir = sys.argv[2]
    slfile = "./%s.sl"%packname

    # luac file output directory
    tmpdir = "__tmp_luapacker__"+packname
    if os.path.isdir(tmpdir):
        rmdirs(tmpdir)

    # luac file, lua file, ...
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
    assert (os.system("./%s/luapacker pack %s %s"%
        (toolpath, lsofile, slfile)) == 0)

    rmdirs(tmpdir)
    os.system("rm %s"%slfile)
