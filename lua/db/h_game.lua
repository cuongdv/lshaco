local shaco = require "shaco"
local tbl = require "tbl"
local sfmt = string.format

local REQ = {}

REQ["L.rolelist"] = function(conn, source, session, acc)
    shaco.trace(sfmt("user %s load rolelist ...", acc))

    local result = assert(conn:execute(sfmt("select roleid, base from x_role where acc=%s", conn.escape_string(acc))))
    if result.err_code then
        shaco.warning(result.message)
        shaco.ret(session, source, shaco.pack(nil))
    else
        shaco.ret(session, source, shaco.pack(result))
    end
end

REQ["C.name"] = function(conn, source, session, name)
    shaco.trace(sfmt("User ask check role name %s ...", name))
    local name = conn.escape_string(name)
    local result = conn:execute(sfmt("select roleid from x_role where name=%s", name))
    tbl.print(result, "C.name")
    local err
    if result.err_code then
        err = 2
    elseif #result > 0 then
        err = 1
    else
        err = 0
    end 
    shaco.ret(session, source, shaco.pack(err))
end

REQ["I.role"] = function(conn, source, session, v)
    local acc = conn.escape_string(v.acc)
    local name = conn.escape_string(v.name)
    local base = conn.escape_string(v.base)
    local result = conn:execute(sfmt("insert into x_role (acc,name,base) values (%s,%s,%s)", acc,name,base))
    local roleid
    if result.err_code then
        roleid = 0
        shaco.warning(sfmt("user %s insert fail: %s", v.acc, result.message))
    else
        roleid = result.last_insert_id
        shaco.trace(sfmt("user %s insert role ok", v.acc))
    end
    -- todo
    shaco.ret(session, source, shaco.pack(roleid))
end

REQ["L.role"] = function(conn, source, session, roleid)
    shaco.trace(sfmt("user %u load role ...", roleid))
    local result = conn:execute(sfmt("select info from x_role where roleid=%u", roleid))
    result = result[1]
    shaco.ret(session, source, shaco.pack(result.info))
end

REQ["S.role"] = function(conn, source, session, v)
    local to1 = conn.escape_string(v.base)
    local to2 = conn.escape_string(v.info)
    local result = conn:execute(sfmt("update x_role set base=%s,info=%s where roleid=%u", to1, to2, v.roleid))
    if result.err_code then
        shaco.warning(sfmt("role %u save fail: %s", v.roleid, result.message))
    else
        shaco.trace(sfmt("role %u save ok", v.roleid))
    end
end

REQ["L.ex"] = function(conn, source, session, v)
    shaco.trace(sfmt("user %u load %s ...", v.roleid, v.name))
    local result = conn:execute(sfmt("select data from x_%s where roleid=%u", v.name, v.roleid))
    result = result[1]
    shaco.ret(session, source, shaco.pack(result and result.data or nil))
end

REQ["S.ex"] = function(conn, source, session, v)
    local to = conn.escape_string(v.data)
    local result = conn:execute(sfmt("insert into x_%s (roleid,data) values (%d,%s) on duplicate key update data=%s", 
        v.name, v.roleid, to, to))
    if result.err_code then
        shaco.warning(sfmt("role %u save %s fail: %s", v.roleid, v.name, result.message))
    else
        shaco.trace(sfmt("role %u save %s ok", v.roleid, v.name))
    end
end

return REQ
