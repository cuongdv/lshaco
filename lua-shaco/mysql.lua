local shaco = require "shaco"
local socketchannel = require "socketchannel"
local crypt = require "crypt.c"
local mysqlaux = require "mysqlaux.c"
local assert = assert
local sbyte = string.byte
local ssub = string.sub
local sgsub = string.gsub
local schar = string.char
local sunpack = string.unpack
local spack = string.pack
local sformat = string.format
local sfind = string.find
local srep = string.rep

local CLIENT_PLUGIN_AUTH = 0x00080000
local CLIENT_SECURE_CONNECTION = 0x00008000
local CLIENT_PROTOCOL_41 = 0x00000200
local CLIENT_PLUGIN_AUTH_LENENC_CLIENT_DATA = 0x00200000
local CLIENT_CONNECT_WITH_DB = 0x00000008
local CLIENT_CONNECT_ATTRS = 0x00100000
local CLIENT_SESSION_TRACK = 0x00800000

local SERVER_SESSION_STATE_CHANGED = 0x4000

local function native_password(s, key)
    if s == "" then
        return ""
    end
    local t1 = crypt.sha1(s)
    local t2 = crypt.sha1(key..crypt.sha1(t1))
    local i = 0
    return sgsub(t1, ".", function(c) 
        i=i+1
        return schar(sbyte(c)~sbyte(t2,i))
    end)
end

local function extract_int1(s, pos)
    return sbyte(s, pos), pos+1
end

local function extract_int2(s, pos)
    return sunpack("<I2",s,pos), pos+2
end

local function extract_int3(s, pos)
    return sunpack("<I3",s,pos), pos+3
end

local function extract_int4(s, pos)
    return sunpack("<I4",s,pos), pos+4
end

local function extract_int8(s, pos)
    return sunpack("<I8",s,pos), pos+8
end

local function lenenc_int(s, pos)
    local b1 = sbyte(s, pos)
    if b1 < 0xfb then
        return b1, pos+1
    elseif b1 == 0xfc then
        return extract_int2(s, pos+1)
    elseif b1 == 0xfd then
        return extract_int3(s, pos+1)
    elseif b1 == 0xfe then
        return extract_int8(s, pos+1)
    elseif b1 == 0xfb then
        return nil, pos+1 -- NULL is sent as 0xfb in ResultRow coloum
    else
        error("Lenenc_int error")
    end
end

local function string_null(s, pos)
    local p2 = sfind(s, "\0", pos, true)
    assert(p2)
    return ssub(s,pos,p2-1), p2+1
end

local function string_eof(s, pos)
    return ssub(s,pos)
end

local function string_len(s, pos, len)
    return ssub(s,pos,pos+len-1), pos+len
end

local function string_lenenc(s, pos)
    local len, pos = lenenc_int(s,pos)
    if len then
        return ssub(s, pos, pos+len-1), pos+len
    else
        return nil, pos
    end
end

local function rpacket(s, order)
    local l = #s
    return spack("<I3B", l, order)..s
end

local function read_header(channel)
    local s = channel:read(4)
    return extract_int3(s,1), sbyte(s,4)
end

local function read_packet(channel)
    local payload_length, sequence_id = read_header(channel)
    assert(payload_length > 0)
    return channel:read(payload_length)
end

local function read_ok_packet(channel, s)
    local pack = { type="OK" }
    if #s > 1 then -- #s==1 in if row is empty in read one row
        local pos = 2
        pack.effected_rows, pos = lenenc_int(s, pos)
        pack.last_insert_id, pos = lenenc_int(s, pos)
        pack.status_flag, pos = extract_int2(s, pos)
        pack.warnings, pos = extract_int2(s, pos)
        if pos < #s then
            --if (0 & CLIENT_SESSION_TRACK) ~= 0 then -- todo
                pack.info, pos = string_lenenc(s, pos)
                if (pack.status_flag & SERVER_SESSION_STATE_CHANGED) ~= 0 then
                    pack.session_state_changes = string_lenenc(s, pos)
                end
            --else
                --pack.info = string_eof(s, pos)
            --end
        end
    end
    return pack
end

local function read_err_packet(channel, s)
    local pack = {type="ERR"}
    pack.err_code = extract_int2(s,2)
    assert(sbyte(s,4)==35) -- '#'
    pack.sql_state = ssub(s,5,9)
    pack.message = ssub(s,10)
    return pack
end

local function read_eof_packet(channel, s)
    local pack = {}
    pack.warnings = extract_int2(s,2)
    pack.status_flag = extract_int2(s,4)
    return pack
end

local function read_generic_response(channel, special_response, ...)
    local payload_length, sequence_id = read_header(channel)
    assert(payload_length > 0)
    local s = channel:read(payload_length)
    local header = sbyte(s,1)
    if header == 0x00 then
        return read_ok_packet(channel,s)
    elseif header == 0xff then
        return read_err_packet(channel,s)
    elseif header == 0xfe then
        return "EOF"--, read_eof_packet(channel,s)
    else
        if special_response then
            return special_response(channel,s, ...)
        else
            error("Unknow generic response "..sformat("%0x",header))
        end
    end
end

local function read_column(channel)
    local s = read_packet(channel)
    local column = {}
    local pos = 1
    column.catalog, pos = string_lenenc(s,pos)
    column.schema, pos = string_lenenc(s,pos)
    column.table, pos = string_lenenc(s,pos)
    column.org_table, pos = string_lenenc(s,pos)
    column.name, pos = string_lenenc(s,pos)
    column.org_name, pos = string_lenenc(s,pos)
    column.length_of_fixed_length_fields, pos = lenenc_int(s,pos)
    assert(column.length_of_fixed_length_fields == 0x0c)
    column.character_set, pos = extract_int2(s,pos)
    column.column_length, pos = extract_int4(s,pos)
    column.type, pos = extract_int1(s,pos)
    column.flags, pos = extract_int2(s,pos)
    column.decimals, pos = extract_int1(s,pos)
    assert(sbyte(s,pos)==0)
    assert(sbyte(s,pos+1)==0)
    pos=pos+2
    --if command was COM_FIELD_LIST {
        --lenenc_int     length of default-values
        --string[$len]   default values
    --}
    return column
end

local function read_row_compact(channel, s, pack, columns)
    local pack = {}
    local pos, v
    pos = 1
    for i=1, #columns do
        v, pos = string_lenenc(s,pos)
        pack[#pack+1] = v
    end
    return pack
end

local function read_row(channel, s, columns)
    local pack = {}
    local pos, v
    pos = 1
    for _, c in ipairs(columns) do
        v, pos = string_lenenc(s,pos)
        pack[c.name] = v
    end
    return pack
end

local function read_resultset(channel, s, self)
    local column_count, pos = lenenc_int(s, 1)
    -- column definition
    local columns = {}
    for i=1,column_count do
        columns[#columns+1] = read_column(channel)
    end
    -- eof
    assert(read_generic_response(channel) == "EOF")
    -- row
    local rows = {}
    local result
    while true do
        result = read_generic_response(channel, self.__row_reader, columns)
        if result == "EOF" then
            break
        elseif result.type == nil then
            rows[#rows+1] = result
        end
    end
    if result == "EOF" or
       result.type == "OK" then
        return rows
    elseif result.type == "ERR" then
        return result
    else
        return {type="ERR", err_code=-1, message="Unknown resultset response"}
    end
end

local function read_handshake(channel)
    -- Initial Handshake Packet
    local pack = {}
    pack.payload_length, pack.sequence_id = read_header(channel)
    local s = channel:read(pack.payload_length)
    -- Protocol::HandshakeV10
    local pos = 1
    pack.protocol_version, pos = extract_int1(s,pos)
    assert(pack.protocol_version==10, 
        "unsupport handshake version "..pack.protocol_version)
    pack.server_version, pos = string_null(s,pos)
    pack.connection_id, pos = extract_int4(s,pos)
    pack.auth_plugin_data, pos = string_len(s,pos,8)
    pos=pos+1  -- skip filler
    pack.capability, pos = extract_int2(s,pos)
    if pos < #s then
        pack.character_set, pos = extract_int1(s,pos)
        pack.status_flag, pos = extract_int2(s,pos)
        local capability_hi, auth_plugin_data_len
        capability_hi, pos = extract_int2(s,pos)
        pack.capability = pack.capability + (capability_hi<<16)
        
        --if (pack.capability & CLIENT_PLUGIN_AUTH) ~= 0 then
            auth_plugin_data_len, pos = extract_int1(s,pos)  
        --else                                               
            --pos=pos+1                                      
        --end                                                
        pos=pos+10 -- skip 10

        if (pack.capability & CLIENT_SECURE_CONNECTION) ~= 0 then
            local l, auth_plugin_data_2
            l = math.max(13,auth_plugin_data_len-8)
            auth_plugin_data_2, pos = string_len(s, pos,l)
            pack.auth_plugin_data = pack.auth_plugin_data..auth_plugin_data_2
        end
        if (pack.capability & CLIENT_PLUGIN_AUTH) ~= 0 then
            pack.auth_plugin_name, pos = string_null(s,pos)
        end
    end
    assert((pos-1)==#s)
    --assert((pack.capability & CLIENT_SESSION_TRACK) ~= 0)
    --if (pack.capability & CLIENT_PROTOCOL_41) ~= 0 then
        -- todo check this
        --error("the mysql server unsupport 41")
    --end
    return true, pack
end

local function handshake_response(channel, handshake, user, passwd, db)
    local auth_plugin_name = handshake.auth_plugin_name
    if handshake.auth_plugin_name then
        if handshake.auth_plugin_name ~= "mysql_native_password" and
           handshake.auth_plugin_name ~= "mysql_old_password" then
            error("Unsupport auth plugin "..handshake.auth_plugin_name)
        end
    else
        if (handshake.capability & CLIENT_PROTOCOL_41) ~= 0 and
           (handshake.capability & CLIENT_SECURE_CONNECTION) ~= 0 then
            auth_plugin_name = "mysql_native_password"
        else
            auth_plugin_name = "mysql_old_password" 
        end
    end
    -- now just this method
    assert(auth_plugin_name == "mysql_native_password")
    -- Handshake Response Packet
    -- Protocol::HandshakeResponse41
    local capability = 
        CLIENT_PROTOCOL_41|
        CLIENT_SECURE_CONNECTION|
        CLIENT_PLUGIN_AUTH
    if db then
        capability = capability|CLIENT_CONNECT_WITH_DB
        db = db.."\0"
    else
        db = ""
    end
    passwd = passwd or ""
    passwd = native_password(passwd, ssub(handshake.auth_plugin_data,1,20))
    local s =
    spack("<I4",capability)..
    schar(0,0,0,1)..
    schar(33)..
    srep("\0",23)..
    user.."\0"..
    schar(#passwd)..
    passwd..
    db..
    auth_plugin_name.."\0"
    channel:request(rpacket(s, handshake.sequence_id+1))
end

local function check_response(result)
    if result.type == "OK" then
        return true
    elseif result.type == "ERR" then
        error(result.message)
    else
        error("Unknow response "..t)
    end
end

local mysql = {}
mysql.__index = mysql

local function login_auth(user, passwd, db)
    return function(channel)
        local handshake = channel:response(read_handshake)
        handshake_response(channel, handshake, user, passwd, db)
        local result = channel:response(function(channel)
            return true, read_generic_response(channel)
        end)
        check_response(result)
    end
end

function mysql.connect(opts)
    local channel = socketchannel.create{ 
        host = opts.host, 
        port = opts.port,
        auth = login_auth(opts.user, opts.passwd, opts.db),
    }
    local self = setmetatable({
        __channel = channel,
        __row_reader = opts.compact and read_row_compact or read_row,
    }, mysql)
    local ok, err = channel:connect()
    if not ok then
        error(sformat("Mysql connect %s:%s fail %s", opts.host, opts.port, err))
    end
    return self
end

function mysql:close()
    self.__channel:close()
end

function mysql:ping()
    local response = self.__channel:request(rpacket(schar(0x0e), 0), 
        function(channel)
            return true, read_generic_response(channel)
        end)
    return check_response(response) 
end

function mysql:use(db)
    local response = self.__channel:request(rpacket(schar(0x02)..db.."\0", 0),
        function(channel)
            return true, read_generic_response(channel)
        end)
    return check_response(response)
end

function mysql:execute(sql)
    return self.__channel:request(rpacket(schar(0x03)..sql, 0),
        function(channel)
            return true, read_generic_response(channel, read_resultset, self)
        end)
end

function mysql:statistics()
    return self.__channel:request(rpacket(schar(0x09), 0),
        function(channel)
            return true, read_generic_response(channel, 
                function(channel, s) return s end)
        end)
end

function mysql:processinfo()
    return self.__channel:request(rpacket(schar(0x0a), 0),
        function(channel)
            return true, read_generic_response(channel, read_resultset, self)
        end)
end

mysql.escape_string = mysqlaux.quote_string

return mysql
