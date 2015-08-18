require "pathconfig"
local args = {...}
if #args < 3 then
    --lua protoc.lua c2p ../../msg/pb ../../proto
    print("usage: protoc.lua op[c2p p2c] input_dir[.h] out_dir")
    return 1
end

local fs = require "fs"
local c2p = require "c2proto"
local p2c = require "proto2c"

local op = args[1]
local outdir = args[3]

local function find_proto(protos, name)
    for _, proto in ipairs(protos) do
        if proto.name == name then
            return proto
        end
    end
end

local outfile, out

if op == "c2p" then
    local protos = {}
    local files = fs.getfiles(args[2], ".h")
    for _, f in ipairs(files) do
        local _, _, _, protoname = string.find(f,'(.-)([^\\/]*).h$')
        local proto = c2p.parse_file(f, protoname)
     
        outfile = string.format("%s/%s.proto", outdir, protoname)
        out = io.open(outfile, "w")
        c2p.dump_proto(proto, out) 
        out:close()

        protos[#protos+1] = proto
    end
elseif op == "p2c" then
    local protos = {}
    local files = fs.getfiles(args[2], ".proto")
    local pb_path = args[4] and args[4] or "."
    for _, f in ipairs(files) do
        local _, _, _, protoname = string.find(f,'(.-)([^\\/]*).proto$')
        if string.sub(protoname, 1, 1) ~= "." then
            local proto = p2c.parse_file(f, protoname) 
            protos[#protos+1] = proto
        end
    end
    p2c.fix(protos)
    for _, proto in ipairs(protos) do
        --local outfile, out
        --outfile = string.format("%s/%s.pb.h", outdir, proto.name)
        --out = io.open(outfile, "w")
        --p2c.dump_proto(proto, out) 
        --out:close()

        outfile = string.format("%s/%s.lua", outdir, proto.name)
        out = io.open(outfile, "w")
        p2c.dump_lua(proto, out) 
        out:close()
    end
    --local outfile = string.format("%s/pb_wrapper.h", outdir, protoname)
    --local out = io.open(outfile, "w")
    --local outfile2 = string.format("%s/pb_wrapper.c", outdir, protoname)
    --local out2 = io.open(outfile2, "w")
    --p2c.dump_context(protos, out, out2, "pb_wrapper", pb_path)
    --out:close()
    --out2:close()

    proto = find_proto(protos, "msg_client")
    assert(proto, "protoc.lua no msg_client")

    outfile = string.format("%s/client_msg_sender-incl.h", outdir)
    out = io.open(outfile, "w")
    p2c.dump_sender(proto, out)
    out:close()
 
    outfile = string.format("%s/client_msg_dispatcher-incl.h", outdir)
    out = io.open(outfile, "w")
    p2c.dump_dispatcher(proto, out)
    out:close() 

    outfile = string.format("%s/msg_reqname.lua", outdir)
    out = io.open(outfile, "w")
    p2c.dump_reqname(proto, out)
    out:close() 

    outfile = string.format("%s/msg_resname.lua", outdir)
    out = io.open(outfile, "w")
    p2c.dump_resname(proto, out)
    out:close() 

    --proto = find_proto(protos, "struct")
    --assert(proto, "protoc.lua no struct")
    --outfile = string.format("%s/struct.lua", outdir)
    --out = io.open(outfile, "w")
    --p2c.dump_structgen(proto, out)
    --out:close() 
end

return 0
