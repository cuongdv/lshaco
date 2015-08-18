local lpeg = require "lpeg"

local tinsert = table.insert
local sfind = string.find
local ssub = string.sub
local sfmt = string.format
local supper = string.upper
local lower = string.lower
local smatch = string.match
local srep = string.rep
local ssub = string.sub
local P = lpeg.P
local S = lpeg.S
local R = lpeg.R
local C = lpeg.C
local Cc = lpeg.Cc
local Cs = lpeg.Cs
local Cg = lpeg.Cg
local Ct = lpeg.Ct
local Cmt = lpeg.Cmt
local Carg = lpeg.Carg

local function _MC(pattern)
    return Cmt(C(pattern) * Carg(1), 
        function (_, pos, pattern, context)
            if pos > context.pos then 
                context.pos = pos 
            end 
            return true
        end)
end
local function _M(pattern)
    return Cmt(pattern * Carg(1), 
        function (_, pos, context)
            if pos > context.pos then 
                context.pos = pos 
            end 
            return true
        end)
end
local _MLine = Cmt((P("\n") + "\r\n") * Carg(1), 
        function (_, pos, context)
            if pos > context.pos then
                context.pos = pos
                context.line = context.line + 1
                context.line_pos = pos
            end
            return true
        end)

local _MError = Cmt(Carg(1), function (buffer, pos, context)
        local err_line = ssub(buffer, context.line_pos, 
                sfind(buffer, "\n", context.line_pos))
        local pos = context.pos - context.line_pos
        err_line = sfmt("%s`%s", ssub(err_line, 1, pos), ssub(err_line, pos+1))
        error(sfmt("syntax error [%s:%d:%d]%s", 
            context.file, context.line, pos+1, err_line))
        end)

local blank = S(" \t") + _MLine
local blanks = blank^1
local empty = blank^0
local digit = R("09")
local alpha = R("az", "AZ")
local varname = (alpha + "_") * (alpha + "_" + digit)^0

local scomment = P("//") * (1 - _MLine)^0 * _MLine
local mcomment = P("/*") * (1 - (P("/*")+"*/"))^0 * P("*/")
local comment = scomment + mcomment + blanks

local label = P("required") + "optional" + "repeated"
local ptype = varname
local number = digit^1

local expression = (empty * _M("(")^-1 * empty * _M(S("+-*/"))^-1 * 
    empty * (digit^1 + varname) * _M(")")^-1)^1

local repeat_expression = _M("[") * empty *
   (_M("max") * empty * _M("=") * empty * 
    Cg(Cc(false), "repeat_fix") + 
    Cg(Cc(true),  "repeat_fix")) *
    Cg(_MC(expression), "repeatc") * empty * _M("]")

local comment = Ct(
    Cg(Cc("comment"), "sign") *
    Cg(_MC(scomment + mcomment + blanks), "value"))

local message_field = Ct(
    Cg(Cc("message_field"), "sign") *
    Cg(_MC(label), "label") * blanks * 
    Cg(_MC(varname), "type") * blanks * 
    Cg(_MC(varname), "name") * empty * 
    _M("=") * empty * 
    Cg(_MC(number), "number") * empty * _M(";") *
    (empty * _M("//")*repeat_expression)^-1)

local enum_field = Ct(
    Cg(Cc("enum_field"), "sign") *
    Cg(_MC(varname), "name") * empty * 
   (_M("=") * empty *
    Cg(_MC(expression), "value") * empty)^-1 * _M(S(",;")))

local option_field = Ct(
    Cg(Cc("option_field"), "sign") *
    _M("option") * blanks *
    _M("allow_alias") * empty *
    _M("=") * empty * _M("true") * empty * _M(";"))

local message = Ct(
    Cg(_MC("message"), "sign") * blanks * 
    Cg(_MC(varname), "name") * empty * _M("{") *
    Cg(Ct((message_field + comment)^0), "fields") * empty * 
    _M("}") * _M(S(";"))^0)

local enum = Ct(
    Cg(_MC("enum"), "sign") * blanks *
    Cg(_MC(varname), "name") * empty * _M("{") *
    Cg(Ct((enum_field + option_field + comment)^0), "fields") * empty *
    _M("}") * _M(S(";"))^0)

local import = Ct(
    Cg(_MC("import"), "sign") * blanks *
    _M('"') * empty *
    (varname * _M("/"))^0 *
    Cg(_MC(varname), "value")) * 
    _M(".proto") * empty *
    _M('"') * empty * _M(";")

local pragma = Ct(
    Cg(Cc("pragma"), "sign") *
    Cg(_M("#pragma") * blanks * _M("pack") * empty * 
       _M("(") * empty * _M(digit^-1) * empty * _M(")"), "value"))

local pattern = Ct((import + message + enum + comment + pragma)^0)

-------------------------------------------------------------------------------
-- serialize
-------------------------------------------------------------------------------
local _TYPES = {
    ["bool"]    = "bool",
    --["uint8"]   = "uint8_t",
    --["uint16"]  = "uint16_t",
    ["uint32"]  = "uint32_t",
    ["uint64"]  = "uint64_t",
    --["int8"]    = "int8_t",
    --["int16"]   = "int16_t",
    ["int32"]   = "int32_t",
    ["int64"]   = "int64_t",
    --["fixed32"] = "uint32_t",
    --["fixed64"] = "uint64_t",
    --["sfixed32"]= "int32_t",
    --["sfixed64"]= "int64_t",
    ["float"]   = "float",
    ["double"]  = "double",
    ["string"]  = "char",
    --["bytes"]   = "uint8_t",
}

local _LABELS = {
    ["required"] = "Y",
    ["optional"] = "O",
    ["repeated"] = "R",
}

local _DEFAULT = {
    ["bool"]    = "false",
    --["uint8"]   = "uint8_t",
    --["uint16"]  = "uint16_t",
    ["uint32"]  = "0",
    ["uint64"]  = "0",
    --["int8"]    = "int8_t",
    --["int16"]   = "int16_t",
    ["int32"]   = "0",
    ["int64"]   = "0",
    --["fixed32"] = "uint32_t",
    --["fixed64"] = "uint64_t",
    --["sfixed32"]= "int32_t",
    --["sfixed64"]= "int64_t",
    ["float"]   = "0",
    ["double"]  = "0",
    ["string"]  = "nil",
    --["bytes"]   = "uint8_t",
}

--fix
local function find_message(protos, name) 
    for _, proto in ipairs(protos) do
        for _, b in ipairs(proto) do
            if (b.sign == "message" or b.sign == "enum") and b.name == name then
                return b
            end
        end
    end
end

local function locate_field(protos, m, pname)
    for _, f in ipairs(m.fields) do
        if f.sign == "message_field" then
            if not _TYPES[f.type] then
                f.locate = find_message(protos, f.type)
                assert(f.locate, sfmt('can not identify type `%s` in `%s:%s.%s`', 
                f.type, pname, m.name, f.name))
            end
        end
    end
end

local function field_repeat_and_type(f)
    local ftype = f.type
    if f.locate and f.locate.sign == "enum" then
        ftype = "enum"
    end
    local repeatc = f.repeatc
    if ftype == "string" then
        repeatc = nil 
    end
    return repeatc, ftype
end

local function isum(b)
    return ssub(b.name, 1, 3) == "UM_" 
end
local function isumfile(proto)
    return ssub(proto.name, 1, 8) == "msg_"
end

local function check(proto)
    for _, b in ipairs(proto) do
        if b.sign == "message" and (not isum(b)) then
            local lastnumber = 0 
            for _, f in ipairs(b.fields) do
                if f.sign == "message_field" then
                    assert(tonumber(f.number) > lastnumber,
                    sfmt("field `%s:%s` number has already used", b.name, f.name))
                    lastnumber = tonumber(f.number)
                end
                if f.label == "repeated" then
                    for k, v in pairs(_TYPES) do
                        assert(f.type ~= k, 
                        sfmt("repeated field `%s:%s` should be a struct", b.name, f.name))
                    end
                end
            end
        end
    end
end


local function check_repeat(m)
    for _, f in ipairs(m.fields) do
        if f.sign == "message_field" then
            if field_repeat_and_type(f) then
                m.has_repeat = true
                break
            end
        end
    end
end

local function fix(protos)
    for _, proto in ipairs(protos) do
        for _, b in ipairs(proto) do
            if b.sign == "message" then
                locate_field(protos, b, proto.name)
                check_repeat(b)
            end
        end
    end 
end

--dump proto
local function dump_instruction(t, pre)
    tinsert(t, sfmt('%s/*this file is generate by proto2c.lua do not change it by hand*/\n', pre and pre or ""))
end

local function dump_h_header(outname, t)
    tinsert(t, sfmt("#ifndef __%s_h__\n", outname))
    tinsert(t, sfmt("#define __%s_h__\n", outname))
end

local function dump_h_tail(t)
    tinsert(t, "#endif")
end
    
local function dump_field(f, t) 
    if f.sign == "message_field" then 
        local ftype
        if f.locate then
            if f.locate.sign == "message" then
                ftype = "struct " .. f.type
            else
                ftype = f.type
            end
        else
            ftype = _TYPES[f.type]
        end
        if f.repeatc then
            if (not f.repeat_fix) and f.type ~= "string" then
                tinsert(t, sfmt("uint16_t n%s;\n    ", f.name)) 
            end
            tinsert(t, sfmt("%s %s[%s];", ftype, f.name, f.repeatc))
        else
            tinsert(t, sfmt("%s %s;", ftype, f.name))
        end
    elseif f.sign == "enum_field" then
        local value = f.value and " = " .. f.value or ""
        tinsert(t, f.name .. value .. ",")
    else
        tinsert(t, f.value)
    end
end

local function dump_proto(proto, t) 
    dump_instruction(t)
    dump_h_header(sfmt(lower(proto.name).."_pb"), t)
    tinsert(t, '#include <stdint.h>\n')
    local n=1
    for i=1,#proto do
        local b = proto[i]
        if b.sign == "import" then
            tinsert(t, sfmt('#include "%s.pb.h"', b.value))
        elseif b.sign == "message" or
               b.sign == "enum" then
            n=i
            break
        else
            tinsert(t, b.value)
        end
    end
    tinsert(t, "#pragma pack(1)\n")
    for i=n,#proto do
        local b = proto[i]
        if b.sign == "message" then
            tinsert(t, sfmt("struct %s {", b.name))
            if isum(b) then
                tinsert(t, "\n\t_UM_HEADER;")
            end
            for _, f in ipairs(b.fields) do
                dump_field(f, t)
            end
            tinsert(t, "};")
        elseif b.sign == "enum" then
            tinsert(t, sfmt("typedef enum %s {", b.name))
            for _, f in ipairs(b.fields) do
                dump_field(f, t)
            end
            tinsert(t, sfmt("} %s;", b.name))
        else
            tinsert(t, b.value)
        end
    end
    tinsert(t, "#pragma pack()\n")
    dump_h_tail(t)
end

--dump pb_wrapper
local function dump_head(outname, t)
    tinsert(t, sfmt("#ifndef __%s_h__\n", outname))
    tinsert(t, sfmt("#define __%s_h__\n", outname))
end

local function dump_tail(t)
    tinsert(t, "#endif")
end

local function dump_pbh(protos, t)
    tinsert(t, '\n')
    tinsert(t, '#include "msg.h"\n')
    for _, proto in ipairs(protos) do
        if not isumfile(proto) then
            tinsert(t, sfmt('#include "%s.pb.h"\n', proto.name))
        end
    end
    tinsert(t, '\n')
end

local function dump_include(outname, t)
    tinsert(t, sfmt([[
#include "%s.h"
#include "pbc.h" 
#include "shaco.h"
#include "util.h"

]], outname))    
end

local function locate_proto(protos, name)
    for _, proto in ipairs(protos) do
        if proto.name == name then
            return proto
        end
    end
end

local function dump_pblist(protos, pb_path, t) 
    ps = {}
    for _, proto in ipairs(protos) do
        if not isumfile(proto) then
            tinsert(ps, proto)
        end
    end
    -- pbc must register dependency first
    rs = {} 
    for _, proto in ipairs(ps) do
        for _, b in ipairs(proto) do
            if b.sign == "import" then
                local p = locate_proto(ps, b.value)
                if p then
                    if not locate_proto(rs, b.value) then
                        tinsert(rs, p)
                    end
                end
            end
        end
    end
    for _, proto in ipairs(ps) do
        if not locate_proto(rs, proto.name) then
            tinsert(rs, proto)
        end
    end
    for _, proto in ipairs(rs) do
        tinsert(t, sfmt('       "%s/%s.pb",\n', pb_path, proto.name))
    end
end

local function dump_reader(t)
    tinsert(t, [[
static int read_file(const char *filename , struct pbc_slice *slice) {
    FILE *f = fopen(filename, "rb");
    if (f == NULL) {
        slice->buffer = NULL;
        slice->len = 0;
        sh_error("pb read fail: `%s`", filename);
        return 1;
    }
    fseek(f,0,SEEK_END);
    slice->len = ftell(f);
    fseek(f,0,SEEK_SET);
    slice->buffer = malloc(slice->len);
    fread(slice->buffer, 1 , slice->len , f);
    fclose(f);
    return 0;
}
]])
    tinsert(t, [[
static int pb_read(struct pbc_env *env, const char *name) {
    struct pbc_slice slice;
    if (read_file(name, &slice))
        return 1;
    if (slice.buffer == NULL)
        return 1;
    int r = pbc_register(env, &slice);
    if (r) {
        sh_error("pb register fail: `%s`, %s", name, pbc_error(env));
        free(slice.buffer);
        return 1;
    };
    free(slice.buffer);
    return 0;
}
]])
end

local function dump_init(protos, outname, pb_path, t)
    dump_reader(t)
    tinsert(t, [[
struct pbc_env *pb_create() {
    const char *PBLIST[] = {
]])
    dump_pblist(protos, pb_path, t)
    tinsert(t, [[
    };
    struct pbc_env * env = pbc_new();
    int i;
    for (i=0; i<(int)countof(PBLIST); ++i) {
        if (pb_read(env, PBLIST[i])) {
            pbc_delete(env);
            return NULL;
        }
    }
    return env;
}
]])
end

local function dump_fini(protos, outname, t)
    tinsert(t, [[
void pb_free(struct pbc_env *env) {
    if (env) {
        pbc_delete(env);
    }
}
]])
end

local function dump_pack_field(f, t)
    local repeatc, ftype = field_repeat_and_type(f)
    local tab = ""
    if repeatc then
        if f.repeat_fix then
            tinsert(t, sfmt('\tfor (i=0; i<(int)countof(s->%s); ++i) {\n', f.name))
        else
            tinsert(t, sfmt('\tfor (i=0; i<(int)sh_min(countof(s->%s), s->n%s); ++i) {\n', f.name, f.name))
        end
        tab = "\t"
    end
    local fun, p3, p4
    if repeatc then
        p3 = sfmt("s->%s[i]", f.name)
    else
        p3 = sfmt("s->%s", f.name) 
    end
    if ftype == "string" then
        fun = 'pbc_wmessage_string'
        p4  = ', -1'
    elseif ftype == "bool" or
           ftype == "uint32" then
        fun = 'pbc_wmessage_integer'
        p4  = ', 0'
    elseif ftype == "int32" then
        fun = 'pbc_wmessage_integer'
        p4  = sfmt(', %s<0 ? -1:0', p3)
    elseif ftype == "enum" then
        fun = 'pbc_wmessage_integer'
        p4  = sfmt(', %s<0 ? -1:0', p3)
    elseif ftype == "int64" or
           ftype == "uint64" then
        fun = 'pbc_wmessage_integer'
        p4  = sfmt(', %s>>32', p3)
    elseif ftype == "float" or
           ftype == "double" then
        fun = 'pbc_wmessage_real'
        p4  = ''
    end
    if f.locate and f.locate.sign == "message" then
        assert(not fun)
        tinsert(t, sfmt('\t%sstruct pbc_wmessage *m_%s = pbc_wmessage_message(m, "%s");\n', 
            tab, f.name, f.name))
        tinsert(t, sfmt('\t%spb_write_%s(m_%s, &(%s));\n', 
            tab, f.locate.name, f.name, p3))
    else
        assert(fun)
        tinsert(t, sfmt('\t%s%s(m, "%s", %s%s);\n', tab, fun, f.name, p3, p4)) 
    end
    if repeatc then
        tinsert(t, sfmt('\t}\n'))
    end 
end

local function dump_write_decl(m, t)
    tinsert(t, sfmt('static int pb_write_%s(struct pbc_wmessage *m, const struct %s *s);\n', 
    m.name, m.name))
end

local function dump_write(m, t)
    tinsert(t, sfmt('static int pb_write_%s(struct pbc_wmessage *m, const struct %s *s) {\n', 
    m.name, m.name))
    if m.has_repeat then
        tinsert(t, '\tint i;\n');
    end
    for _, f in ipairs(m.fields) do
        if f.sign == "message_field" then
            dump_pack_field(f, t)
        end
    end
    tinsert(t, '\treturn 0;\n')
    tinsert(t, '}\n')
end

local function dump_unpack_field(f, t)
    local repeatc, ftype = field_repeat_and_type(f)
    local tab = ""
    local idx = "0"
    if repeatc then
        if f.repeat_fix then
            tinsert(t, sfmt('\tuint16_t n%s = pbc_rmessage_size(m, "%s");\n', f.name, f.name))
            tinsert(t, sfmt('\tfor (i=0; i<(int)sh_min(countof(s->%s), n%s); ++i) {\n', f.name, f.name))
        else
            tinsert(t, sfmt('\ts->n%s = pbc_rmessage_size(m, "%s");\n', f.name, f.name))
            tinsert(t, sfmt('\tfor (i=0; i<(int)sh_min(countof(s->%s), s->n%s); ++i) {\n', f.name, f.name))
        end
        tab = "\t"
        idx = "i"
    end
    local fun, p3, p4, lvalue
    if repeatc then
        p3 = "i"
        lvalue = sfmt("s->%s[i]", f.name)
    else
        p3 = "0"
        lvalue = sfmt("s->%s", f.name)
    end
    if ftype == "string" then
        fun = 'pbc_rmessage_string'
        p4  = ', NULL'
    elseif ftype == "bool" or
           ftype == "uint32" then
        fun = 'pbc_rmessage_integer'
        p4  = ', NULL'
    elseif ftype == "int32" then
        fun = 'pbc_rmessage_integer'
        p4  = ', NULL'
    elseif ftype == "enum" then
        fun = sfmt('(%s)pbc_rmessage_integer', f.type)
        p4  = ', NULL'
    elseif ftype == "int64" or
           ftype == "uint64" then
        fun = 'pbc_rmessage_integer'
        p4  = '&hi'
    elseif ftype == "float" or
           ftype == "double" then
        fun = 'pbc_rmessage_real'
        p4  = ''
    end
    if f.locate and f.locate.sign == "message" then
        assert(not fun)
        tinsert(t, sfmt('\t%sstruct pbc_rmessage *m_%s = pbc_rmessage_message(m, "%s", %s);\n', 
            tab, f.name, f.name, idx))
        tinsert(t, sfmt('\t%spb_read_%s(m_%s, &(%s));\n', 
            tab, f.locate.name, f.name, lvalue))
    elseif ftype == "string" then
        assert(fun)
        tinsert(t, sfmt('\t%ssh_strncpy(%s, %s(m, "%s", %s%s), sizeof(%s));\n', 
        tab, lvalue, fun, f.name, p3, p4, lvalue)) 
    else
        assert(fun)
        tinsert(t, sfmt('\t%s%s = %s(m, "%s", %s%s);\n', tab, lvalue, fun, f.name, p3, p4)) 
    end
    if repeatc then
        tinsert(t, sfmt('\t}\n'))
    end 
end

local function dump_read_decl(m, t)
    tinsert(t, sfmt('static int pb_read_%s(struct pbc_rmessage *m, struct %s *s);\n', 
    m.name, m.name))
end

local function dump_read(m, t)
    tinsert(t, sfmt('static int pb_read_%s(struct pbc_rmessage *m, struct %s *s) {\n', 
    m.name, m.name))
    if m.has_repeat then
        tinsert(t, '\tint i;\n');
    end
    for _, f in ipairs(m.fields) do
        if f.sign == "message_field" then
            dump_unpack_field(f, t)
        end
    end
    tinsert(t, '\treturn 0;\n')
    tinsert(t, '}\n')

end

local function msg_name(pack_name, m)
    local name
    if pack_name then
        return sfmt("%s.%s", pack_name, m.name)
    else
        return m.name
    end
end

local function dump_pack_declare(name, m, t)
    tinsert(t, sfmt([[
int pb_pack_%s(struct pbc_env *env, const struct %s *s, char *buf, int sz);
]], m.name, m.name))
end

local function dump_unpack_declare(name, m, t)
    tinsert(t, sfmt([[
int pb_unpack_%s(struct pbc_env *env, const char *buf, int sz, struct %s *s);
]], m.name, m.name))
end

local function dump_pack(name, m, t)
    tinsert(t, sfmt([[
int pb_pack_%s(struct pbc_env *env, const struct %s *s, char *buf, int sz) { 
    struct pbc_wmessage *m = pbc_wmessage_new(env, "%s");
    if (m == NULL)
        return -1;
    if (pb_write_%s(m, s))
        return -2;
    struct pbc_slice slice;
    pbc_wmessage_buffer(m, &slice);
    if (slice.len <= sz) {
        memcpy(buf, slice.buffer, slice.len);
        pbc_wmessage_delete(m);
        return slice.len;
    } else {
        pbc_wmessage_delete(m);
        return 0;
    } 
}
]], m.name, m.name, name, m.name))
end

local function dump_unpack(name, m, t)
    tinsert(t, sfmt([[
int pb_unpack_%s(struct pbc_env *env, const char *buf, int sz, struct %s *s) {
    struct pbc_slice slice = { (void*)buf, sz };
    struct pbc_rmessage *m = pbc_rmessage_new(env, "%s", &slice);
    if (m == NULL) {
        sh_error("%s: %%s", pbc_error(env));
        return 1;
    }
    if (pb_read_%s(m, s))
        return 1;
    pbc_rmessage_delete(m);
    return 0;
}
]], m.name, m.name, name, m.name, m.name))
end

local function dump_declare(protos, t)
    tinsert(t, [[
struct pbc_env;
struct pbc_env *pb_create();
void pb_free(struct pbc_env *env);

]])
    for _, proto in ipairs(protos) do
        for _, b in ipairs(proto) do
            if b.sign == "message" and not isum(b) then
                name = msg_name(pack_name, b)
                dump_pack_declare(name, b, t)
                dump_unpack_declare(name, b, t)
                tinsert(t, '\n')
            end
        end
    end
end

local function dump_cpp(protos, outname, pb_path, t)
    dump_instruction(t)
    dump_include(outname, t)
    dump_init(protos, outname, pb_path, t)
    dump_fini(protos, outname, t)
    for _, proto in ipairs(protos) do
        for _, b in ipairs(proto) do
            if b.sign == "message" and not isum(b) then
                dump_write_decl(b, t)
                dump_read_decl(b, t)
            end
        end
    end
    for _, proto in ipairs(protos) do
        for _, b in ipairs(proto) do
            if b.sign == "message" and not isum(b) then
                dump_write(b, t)
                dump_read(b, t)
            end
        end
    end
    for _, proto in ipairs(protos) do
        for _, b in ipairs(proto) do
            if b.sign == "message" and not isum(b) then
                name = msg_name(pack_name, b)
                dump_pack(name, b, t)
                dump_unpack(name, b, t)
            end
        end
    end
end

local function dump_h(protos, outname, t)
    dump_instruction(t)
    dump_head(outname, t)
    dump_pbh(protos, t)

    dump_declare(protos, t)
    
    dump_tail(t)
end

-- to lua
local function dump_lua(proto, t) 
    dump_instruction(t, "--")
    local n=1
    for i=1,#proto do
        local b = proto[i]
        local begin=false
        if b.sign == "enum" then
            begin=true
            if begin then
                tinsert(t, sfmt('--%s', b.name))
                for _, f in ipairs(b.fields) do
                    if f.sign == "enum_field" then
                        tinsert(t, sfmt('rawset(_ENV, "%s", %d)', f.name, f.value))
                    elseif f.value then
                        local v = f.value
                        v = string.gsub(v, "//", "--")
                        v = string.gsub(v, "/%*", "--")
                        v = string.gsub(v, "%*/", "--")
                        tinsert(t, v)
                    end
                end
            end
        elseif b.sign == "comment" then
            if begin then
                tinsert(t, "--"..b.value)
            end
        else
            if begin then
                break
            end
        end
    end
end

-- to sender
local function dump_senderdef(t)
    tinsert(t, [[
template<typename T>
struct CMsg
{
    CMsgHeader header;
    T body;
    enum {MSGID=0};
};
]])
end
local function dump_senderone(t, f)
    local idname = f.name
    local mname = ssub(f.name, 3, -1)
    tinsert(t, sfmt([[
template <>
struct CMsg<%s>
{
    CMsgHeader header;
    %s body;
    enum {MSGID=%s};
};
]], mname, mname, idname))
end

local function dump_sender(proto, t)
    dump_instruction(t)
    local block
    for i=1,#proto do
        local b = proto[i]
        if b.sign == "enum" and b.name == "IDUM_CLI" then
            block = b
            break
        end
    end
    assert(block, "dump sender but no IDUM_CLI")
    dump_senderdef(t)

    local begin
    for _, f in ipairs(block.fields) do
        if f.sign == "enum_field" then
            if f.name == "IDUM_GATEE" then
                break
            end
            if f.name == "IDUM_GATEB" then
                begin = true
            else
                if begin then
                    dump_senderone(t, f)
                end
            end
        end
    end
end

-- to dispatcher
local function dump_dispatcherone(t, f)
    local idname = f.name
    local mname = ssub(f.name, 3, -1)
    tinsert(t, sfmt([[
case %s: {
    %s proto_msg;
    if (!proto_msg.ParseFromArray(header+1, header->length-2))
    {
        return;
    }
    On%s(header, proto_msg);
    break;
}
]], idname, mname, mname))
end

local function dump_dispatcher(proto, t)
    dump_instruction(t)
    local block
    for i=1,#proto do
        local b = proto[i]
        if b.sign == "enum" and b.name == "IDUM_CLI" then
            block = b
            break
        end
    end
    assert(block, "dump sender but no IDUM_CLI")
    tinsert(t, "switch(header->msg_id) {\n")
    local begin
    for _, f in ipairs(block.fields) do
        if f.sign == "enum_field" then
            if f.name == "IDUM_CLIE" then
                break
            end
            if f.name == "IDUM_CLIB" then
                begin = true
            else
                if begin then
                    dump_dispatcherone(t, f)
                end
            end
        end
    end
    tinsert(t, "default;break;}")
end

--to msgname
local function dump_msgname(proto, t, enum_name, out_name, enum_begin, enum_end)
    dump_instruction(t, '--')
    tinsert(t, 'require "msg_client"\n')
    local block
    for i=1,#proto do
        local b = proto[i]
        if b.sign == "enum" and b.name == enum_name then
            block = b
            break
        end
    end
    assert(block, sfmt("dump %s but no %s", out_name, enum_name))

    tinsert(t, sfmt("local %s={}\n", out_name))
    local begin
    for _, f in ipairs(block.fields) do
        if f.sign == "enum_field" then
            if f.name == enum_end then
                break
            end
            if f.name == enum_begin then
                begin = true
            else
                if begin then
                    tinsert(t, sfmt('%s[%s] = "%s"\n', out_name, f.name, ssub(f.name, 3, -1)))
                end
            end
        end
    end
    tinsert(t, sfmt("return %s", out_name))
end
local function dump_reqname(proto, t)
    dump_msgname(proto, t, "IDUM_CLI", "MSG_REQNAME", "IDUM_GATEB", "IDUM_GATEE")
end
local function dump_resname(proto, t)
    dump_msgname(proto, t, "IDUM_CLI", "MSG_RESNAME", "IDUM_CLIB", "IDUM_CLIE")
end

--to structgen
local function dump_structgenone(t, block)
    tinsert(t, sfmt("function GEN_%s()\n", block.name))
    tinsert(t, "\treturn {\n")
    for _, f in ipairs(block.fields) do
        if f.sign == "message_field" then
            tinsert(t, sfmt("\t\t%s = %s,\n", f.name, _DEFAULT[f.type] or "nil"))
        end
    end
    tinsert(t, "\t}\n")
    tinsert(t, "end\n")
end

local function dump_structgen(proto, t)
    dump_instruction(t, '--')
    for i=1,#proto do
        local b = proto[i]
        if b.sign == "message" then
            dump_structgenone(t, b)
        end
    end
end

-------------------------------------------------------------------------------
-- parser
-------------------------------------------------------------------------------
local plp = {}

local function _parse(s, protoname, filename)
    local context = { file=filename, pos=0, line=1, line_pos=0 }
    local proto = lpeg.match(pattern * (-1 + _MError), s, 1, context)
    proto.name = protoname 
    check(proto)
    return proto
end

function plp.parse_string(s, protoname)
    return _parse(s, protoname, "")
end

function plp.parse_file(filename, protoname)
    print('>> parsing file ' .. filename)
	local fp = io.open(filename, "r")
	local s = fp:read("*a")
	fp:close()
	return _parse(s, protoname, filename)
end

function plp.fix(protos)
    fix(protos)
end

function plp.dump_proto(proto, out)
    local old_output = io.output()
    if out then
        io.output(out)
    end
    local t = {}
    dump_proto(proto, t)
    io.write(table.concat(t))
    io.output(old_output)
end

function plp.dump_context(protos, out, out2, outname, pb_path)
    local old_output = io.output()
    
    io.output(out)
    local t = {}
    dump_h(protos, outname, t)
    io.write(table.concat(t))

    io.output(out2)
    local t2 = {}
    dump_cpp(protos, outname, pb_path, t2)
    io.write(table.concat(t2))

    io.output(old_output)
end

function plp.dump_lua(proto, out)
    local old_output = io.output()
    if out then
        io.output(out)
    end
    local t = {}
    dump_lua(proto, t)
    io.write(table.concat(t))
    io.output(old_output)
end

function plp.dump_sender(proto, out)
    local old_output = io.output()
    if out then
        io.output(out)
    end
    local t= {}
    dump_sender(proto, t)
    io.write(table.concat(t))
    io.output(old_output)
end

function plp.dump_dispatcher(proto, out)
    local old_output = io.output()
    if out then
        io.output(out)
    end
    local t= {}
    dump_dispatcher(proto, t)
    io.write(table.concat(t))
    io.output(old_output)
end

function plp.dump_reqname(proto, out)
    local old_output = io.output()
    if out then
        io.output(out)
    end
    local t= {}
    dump_reqname(proto, t)
    io.write(table.concat(t))
    io.output(old_output)
end

function plp.dump_resname(proto, out)
    local old_output = io.output()
    if out then
        io.output(out)
    end
    local t= {}
    dump_resname(proto, t)
    io.write(table.concat(t))
    io.output(old_output)
end

function plp.dump_structgen(proto, out)
    local old_output = io.output()
    if out then
        io.output(out)
    end
    local t= {}
    dump_structgen(proto, t)
    io.write(table.concat(t))
    io.output(old_output)
end

return plp
