local lpeg = require "lpeg"

local tinsert = table.insert
local sfind = string.find
local ssub = string.sub
local sfmt = string.format
local supper = string.upper
local smatch = string.match
local srep = string.rep
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

local ptype = varname
local number = digit^1

local expression = (empty * _M("(")^-1 * empty * _M(S("+-*/"))^-1 * 
    empty * (digit^1 + varname) * _M(")")^-1)^1

local repeat_expression = _M("[") * empty *
    Cg(_MC(expression), "repeatc") * empty * _M("]")

local comment = Ct(
    Cg(Cc("comment"), "sign") *
    Cg(_MC(scomment + mcomment + blanks), "value"))

local message_field = Ct(
    Cg(Cc("message_field"), "sign") *
    ((_M("struct") * empty)^-1) *
    Cg(_MC(varname), "type") * empty * 
    Cg(_MC(varname), "name") * empty * 
    repeat_expression^0 * _M(";"))

local enum_field = Ct(
    Cg(Cc("enum_field"), "sign") *
    Cg(_MC(varname), "name") * empty * 
   (_M("=") * empty *
    Cg(_MC(expression), "value") * empty)^-1 * _M(S(","))^-1)

local message = Ct(
    Cg(_MC("struct"), "sign") * blanks * 
    Cg(_MC(varname), "name") * empty * _M("{") *
    Cg(Ct((message_field + comment)^0), "fields") * empty * 
    _M("}") * _M(S(";"))^0)

local enum = Ct(
    Cg(_MC("enum"), "sign") * blanks *
    Cg(_MC(varname), "name") * empty * _M("{") *
    Cg(Ct((enum_field + comment)^0), "fields") * empty *
    _M("}") * _M(S(";"))^0)

local import = Ct(
    Cg(Cc("import"), "sign") *
    _M("#include") * blanks * _M(S('"<')) * _MC(varname) * (_M('.') * _M(varname))^0 *
    _M(S('">"')) * blanks)

local head = Ct(
    Cg(Cc("head"), "sign") *
    Cg(_M("#ifndef") * blanks * _MC(varname) * blanks *
       _M("#define") * blanks * _MC(varname) * blanks))

local tail= Ct(
    Cg(Cc("tail"), "sign") * 
    _M("#endif")) * empty

local pragma = Ct(
    Cg(Cc("pragma"), "sign") *
    _M("#pragma") * blanks * _M("pack") * empty * 
    _M("(") * empty * _M(digit^-1) * empty * _M(")"), "value")

local pattern = Ct(comment^0 * head^-1 * (import + message + enum + comment + pragma)^0 * tail^-1 * comment^0)

-------------------------------------------------------------------------------
-- serialize
-------------------------------------------------------------------------------
local _TYPES = {
    ["bool"]      = "bool",
    ["uint8_t"]   = "uint32",
    ["uint16_t"]  = "uint32",
    ["uint32_t"]  = "uint32",
    ["uint64_t"]  = "uint64",
    ["int8_t"]    = "int32",
    ["int16_t"]   = "int32",
    ["int32_t"]   = "int32",
    ["int"]   = "int32",
    ["int64_t"]   = "int64",
    ["float"]     = "float",
    ["double"]    = "double",
    ["char"]      = "string",
}

local function dump_field(f, i, t) 
    if f.sign == "message_field" then 
        local prefix = (f.repeatc and f.type ~= "char") and "repeated" or "optional"
        local suffix = (f.repeatc) and sfmt("//[max=%s] ", f.repeatc) or ""
        local ftype = _TYPES[f.type]
        if not ftype then ftype = f.type end
        tinsert(t, sfmt("%s %s %s = %d;%s", prefix, ftype, f.name, i, suffix))
        return true
    elseif f.sign == "enum_field" then
        local value = f.value and " = " .. f.value or ""
        tinsert(t, f.name .. value .. ";")
        return true
    else
        tinsert(t, f.value)
        return false
    end
end

local function dump_proto(proto, t) 
    for _, b in ipairs(proto) do
        if b.sign == "enum" then
            local order = -1
            local i = -1
            for _, f in ipairs(b.fields) do
                if f.sign == "enum_field" then
                    i = (i == -1) and 1 or 0
                    if i==1 then
                        if not f.value then
                            f.value = "0"
                            order = 0
                        elseif f.value == "0" then
                            order = 0
                        elseif f.value == "1" then
                            order = 1
                        end
                    else
                        if order ~= -1 then
                            order = order+1
                            if not f.value then
                                f.value = sfmt("%s", order)
                            end
                        end
                    end
                end
            end
        end
    end
    for _, b in ipairs(proto) do
        --if b.sign == "import" then
            --tinsert(t, sfmt('package %s;', b.value))
        if b.sign == "struct" then
            tinsert(t, sfmt("message %s {", b.name))
            i = 1
            for _, f in ipairs(b.fields) do
                if dump_field(f, i, t) then
                    i = i+1
                end
            end
            tinsert(t, "}")
        elseif b.sign == "enum" then
            tinsert(t, sfmt("enum %s {", b.name))
            i = 1
            for _, f in ipairs(b.fields) do
                if dump_field(f, i, t) then
                    i = i+1
                end
            end
            tinsert(t, "}")
        else
            tinsert(t, b.value)
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

return plp
