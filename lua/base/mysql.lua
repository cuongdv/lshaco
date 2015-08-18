local shaco = require "shaco"
local socket = require "socket"
local socketchannel = require "socketchannel"
local crypt = require "crypt.c"
local mysqlaux = require "mysqlaux.c"
local tbl = require "tbl"
local string = string
local table = table

local CLIENT_PLUGIN_AUTH = 0x00080000
local CLIENT_SECURE_CONNECTION = 0x00008000
local CLIENT_PROTOCOL_41 = 0x00000200
local CLIENT_PLUGIN_AUTH_LENENC_CLIENT_DATA = 0x00200000
local CLIENT_CONNECT_WITH_DB = 0x00000008
local CLIENT_CONNECT_ATTRS = 0x00100000
local CLIENT_SESSION_TRACK = 0x00800000

local SERVER_SESSION_STATE_CHANGED = 0x4000

local function native_password(s, key)
    local t1 = crypt.sha1(s)
    local t2 = crypt.sha1(key..crypt.sha1(t1))
    local i = 0
    return string.gsub(t1, ".", function(c) 
        i=i+1
        return string.char(string.byte(c)~string.byte(t2,i))
    end)
end

local function extract_int1(s, pos)
    return string.byte(s, pos), pos+1
end

local function extract_int2(s, pos)
    return string.unpack("<I2",s,pos), pos+2
end

local function extract_int3(s, pos)
    return string.unpack("<I3",s,pos), pos+3
end

local function extract_int4(s, pos)
    return string.unpack("<I4",s,pos), pos+4
end

local function extract_int8(s, pos)
    return string.unpack("<I8",s,pos), pos+8
end

local function lenenc_int(s, pos)
    local b1 = string.byte(s, pos)
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
        error("lenenc_int error")
    end
end

local function string_null(s, pos)
    local p2 = string.find(s, "\0", pos, true)
    assert(p2)
    return string.sub(s,pos,p2-1), p2+1
end

local function string_eof(s, pos)
    return string.sub(s,pos)
end

local function string_len(s, pos, len)
    return string.sub(s,pos,pos+len-1), pos+len
end

local function string_lenenc(s, pos)
    local len, pos = lenenc_int(s,pos)
    if len then
        return string.sub(s, pos, pos+len-1), pos+len
    else
        return nil, pos
    end
end

local function rpacket(s, order)
    local l = #s
    return string.pack("<I3B", l, order)..s
end

local function read_header(id)
    local s = assert(socket.read(id,4))
    return extract_int3(s,1), string.byte(s,4)
end

local function read_packet(id)
    local payload_length, sequence_id = read_header(id)
    assert(payload_length > 0)
    return assert(socket.read(id, payload_length))
end

local function read_ok_packet(id, s, pack)
    local pos = 2
    pack.__type = "OK"
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
    return pack
end

local function read_err_packet(id, s, pack)
    pack.__type = "ERR"
    pack.err_code = extract_int2(s,2)
    assert(string.byte(s,4)==35) -- '#'
    pack.sql_state = string.sub(s,5,9)
    pack.message = string.sub(s,10)
    return pack
end

local function read_eof_packet(id, s, pack)
    pack.__type = "EOF"
    pack.warnings = extract_int2(s,2)
    pack.status_flag = extract_int2(s,4)
    return pack 
end

local function read_generic_response(id, special_response, ...)
    local pack = {}
    local payload_length, sequence_id = read_header(id)
    assert(payload_length > 0)
    local s = assert(socket.read(id, payload_length))
    local header = string.byte(s,1)
    if header == 0x00 then
        return read_ok_packet(id,s,pack)
    elseif header == 0xff then
        return read_err_packet(id,s,pack)
    elseif header == 0xfe then
        return read_eof_packet(id,s,pack)
    else
        if special_response then
            return special_response(id,s,pack, ...)
        else
            error("unknow generic response "..string.format("%0x",header))
        end
    end
end

local function read_column(id)
    local s = read_packet(id)
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
    assert(string.byte(s,pos)==0)
    assert(string.byte(s,pos+1)==0)
    pos=pos+2
    --if command was COM_FIELD_LIST {
        --lenenc_int     length of default-values
        --string[$len]   default values
    --}
    return column
end

local function read_row_compact(id, s, pack, columns)
    local pos, v
    pos = 1
    for i=1,#columns do
        v, pos = string_lenenc(s,pos)
        table.insert(pack, v)
    end
    return pack
end

local function read_row(id, s, pack, columns)
    local pos, v
    pos = 1
    for i=1,#columns do
        v, pos = string_lenenc(s,pos)
        pack[columns[i].name] = v
    end
    return pack
end

local function read_resultset(id, s, pack, self)
    local column_count, pos = lenenc_int(s, 1)
    -- column definition
    local columns = {}
    for i=1,column_count do
        table.insert(columns, read_column(id))
    end
    -- eof
    local gres = read_generic_response(id)
    assert(gres.__type == "EOF")
    -- row
    local rows = {}
    while true do
        gres = read_generic_response(id, self.__row_reader, columns)
        if gres.__type == nil then
            table.insert(rows, gres)
        else break end
    end
    if gres.__type == "EOF" or
       gres.__type == "OK" then
        return rows
    elseif gres.__type == "ERR" then
        return nil, gres.message
    else
        return nil, "unknown resultset response"
    end
end

local function read_handshake(id)
    -- Initial Handshake Packet
    local pack = {}
    pack.payload_length, pack.sequence_id = read_header(id)
    local s = assert(socket.read(id, pack.payload_length))
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
    return pack
end

local function handshake_response(id, handshake, user, passwd, db)
    local auth_plugin_name = handshake.auth_plugin_name
    if handshake.auth_plugin_name then
        if handshake.auth_plugin_name ~= "mysql_native_password" and
           handshake.auth_plugin_name ~= "mysql_old_password" then
            error("unsupport auth plugin "..handshake.auth_plugin_name)
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
    passwd = native_password(passwd, string.sub(handshake.auth_plugin_data,1,20))
    local s =
    string.pack("<I4",capability)..
    string.char(0,0,0,1)..
    string.char(33)..
    string.rep("\0",23)..
    user.."\0"..
    string.char(20)..
    passwd..
    db..
    auth_plugin_name.."\0"
    assert(socket.send(id, rpacket(s, handshake.sequence_id+1)))
end

local function check_response(response)
    if response.__type == "OK" then
        return true
    elseif response.__type == "ERR" then
        return false, response.message
    else
        error("unknow response "..response.__type)
    end
end

local mysql = {}
mysql.__index = mysql

local function login_auth(user, passwd, db)
    return function(id)
        local handshake = read_handshake(id)
        handshake_response(id, handshake, user, passwd, db)
        local response = read_generic_response(id)
        assert(check_response(response))
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
        __row_reader = opts.compact and read_row_compat or read_row,
    }, mysql)
    channel:connect()
    return self
end

function mysql:close()
    self.__channel:close()
end

function mysql:ping()
    local response = self.__channel:request(rpacket(string.char(0x0e), 0), 
        function(id)
            return read_generic_response(id)
        end)
    assert(response.__type == "OK")
end

function mysql:use(db)
    local response = self.__channel:request(rpacket(string.char(0x02)..db.."\0", 0),
        function(id)
            return read_generic_response(id)
        end)
    return check_response(response)
end

function mysql:execute(sql)
    local response = self.__channel:request(rpacket(string.char(0x03)..sql, 0),
        function(id)
            return read_generic_response(id, read_resultset, self)
        end)
    return response
end

function mysql:statistics()
    local response = self.__channel:request(rpacket(string.char(0x09), 0),
        function(id)
            return read_generic_response(id, 
                function(id, s, pack) return s end)
        end)
    return response
end

function mysql:processinfo()
    local response = self.__channel:request(rpacket(string.char(0x0a), 0),
        function(id)
            return read_generic_response(id, read_resultset, self)
        end)
    return response
end

mysql.escape_string = mysqlaux.quote_string

return mysql
