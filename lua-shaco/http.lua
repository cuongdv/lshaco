local shaco = require "shaco"
local socket = require "socket"
local httpsocket = require "httpsocket"
local assert = assert
local tonumber = tonumber
local pairs = pairs
local string = string
local table = table

local CHUNK_LIMIT=64*1024

local http = {}

local strcode = {
	[100] = "Continue",
	[101] = "Switching Protocols",
	[200] = "OK",
	[201] = "Created",
	[202] = "Accepted",
	[203] = "Non-Authoritative Information",
	[204] = "No Content",
	[205] = "Reset Content",
	[206] = "Partial Content",
	[300] = "Multiple Choices",
	[301] = "Moved Permanently",
	[302] = "Found",
	[303] = "See Other",
	[304] = "Not Modified",
	[305] = "Use Proxy",
	[307] = "Temporary Redirect",
	[400] = "Bad Request",
	[401] = "Unauthorized",
	[402] = "Payment Required",
	[403] = "Forbidden",
	[404] = "Not Found",
	[405] = "Method Not Allowed",
	[406] = "Not Acceptable",
	[407] = "Proxy Authentication Required",
	[408] = "Request Time-out",
	[409] = "Conflict",
	[410] = "Gone",
	[411] = "Length Required",
	[412] = "Precondition Failed",
	[413] = "Request Entity Too Large",
	[414] = "Request-URI Too Large",
	[415] = "Unsupported Media Type",
	[416] = "Requested range not satisfiable",
	[417] = "Expectation Failed",
    [426] = "Upgrade Required",
	[500] = "Internal Server Error",
	[501] = "Not Implemented",
	[502] = "Bad Gateway",
	[503] = "Service Unavailable",
	[504] = "Gateway Time-out",
	[505] = "HTTP Version not supported",
}

local function unneed_body(code)
    return (code==204) or (code==304) or (math.floor(code/100)==1)
end

local function escape(s)
    return string.gsub(s, "([^A-Za-z0-9_])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
end

local function parse_header(line_t, head_t)
    local name, value, line
    for i=1,#line_t do
        line = line_t[i]
        if line:byte(1) == 9 then -- todo: just one \t ?
            head_t[name] = head_t[name]..line:sub(2)
        else
            name, value = line:match("^(.-):%s*(.*)")
            if name == nil or value == nil then
                return
            end
            name = name:lower()
            if head_t[name] then
                head_t[name] = head_t[name]..","..value
            else
                head_t[name] = value
            end
        end
    end
    return head_t
end

local function chunksize(chunk, read)
    while true do 
        local i = chunk:find("\r\n",1,true)
        if i then
            local size = tonumber(chunk:sub(1,i-1),16)
            return size, chunk:sub(i+2)
        end
        if #chunk > 128 then
            error("Too large chunksize body")
        end
        chunk = chunk..read()
    end
end

local function crlf(chunk, read)
    --if #chunk >=2 then
    --    if chunk:find("^\r\n") then
    --        return chunk:sub(3)
    --    end
    --else
    --    chunk = chunk..assert(socket.read(id, 2-#chunk))
    --    if chunk == "\r\n" then
    --        return ""
    --    end
    --end
    while #chunk < 2 do
        chunk = chunk..read()
    end
    if chunk:find("^\r\n") then
        return chunk:sub(3)
    end
end

local function chunkbody(chunk, read)
    local chunk_t = {}
    local length = 0
    local size
    while true do
        size, chunk = chunksize(chunk, read)
        if size == 0 then break end
        if length+size > CHUNK_LIMIT then
            error("Too large chunkbody")
        end
        --if #chunk >= size then
        --    table.insert(chunk_t, chunk:sub(1,size))
        --    chunk = chunk:sub(size+1)
        --    chunk = crlf(id, chunk, read)
        --    if not chunk then
        --        error("Invalid chunkbody")
        --    end
        --else
        --    chunk = chunk..assert(socket.read(id, size-#chunk))
        --    table.insert(chunk_t, chunk)
        --    chunk = crlf(id, "", read)
        --    if not chunk then
        --        error("Invalid chunkbody")
        --    end
        --end
        while #chunk < size do
            chunk = chunk .. read()
        end
        table.insert(chunk_t, chunk:sub(1,size))
        chunk = chunk:sub(size+1)
        chunk = crlf(chunk, read)
        if not chunk then
            error("Invalid chunkbody")
        end
        length = length + size
    end
    return table.concat(chunk_t), chunk
end

local function statusline(read)
    local chunk = ""
    while true do
        chunk = chunk..read()
        shaco.trace("http statusline start read!")
        local i = chunk:find("\r\n",1,true)
        if i then
            return chunk:sub(1,i), chunk:sub(i+2)
        end
        if #chunk > CHUNK_LIMIT then
            error "Too large status line"
        end
    end
end

local function header(chunk, read)
    local l = 0
    local lines = {}
    while true do
        local i = chunk:find("\r\n",1,true)
        if i then
            if i== 1 then
                return lines, chunk:sub(i+2)
            end
            table.insert(lines, chunk:sub(1,i-1))
            chunk = chunk:sub(i+2)
            l = l+i-1
        else
            if l+#chunk > CHUNK_LIMIT then
                error "Too large header size"
            end
            chunk = chunk..read()
        end
    end
end

local function content(length, chunk, read)
    if length > CHUNK_LIMIT then
        error "Too large content"
    end
    --if length > #chunk then
    --    return chunk..assert(socket.read(id, length-#chunk))
    --else
    --    return chunk
    --end
    while #chunk < length do
        chunk = chunk .. read()
    end
    return chunk
end

local function format_form(form)
    if type(form) ~= "string" then
        local body = {}
        for k, v in pairs(form) do
            if type(k) == "number" then
                v = escape(v)
                table.insert(body, v)
            else
                table.insert(body, string.format("%s=%s", escape(k), escape(v)))
            end
        end
        form = table.concat(body, "&")
    end
    return form
end

local function request(method, host, uri, headers, form, read, send)
    if form then
        headers = headers or 
        { ["content-type"] = "application/x-www-form-urlencoded" }
        form = format_form(form)
    end

    local strhead = "host:"..host.."\r\n"
    if headers then
        for k, v in pairs(headers) do
            strhead = strhead..string.format("%s:%s\r\n", k,v)
        end
    end

    local request_line = method.." "..uri.." HTTP/1.1\r\n"

    local total
    if not form then
        total = string.format("%s%scontent-length:0\r\n\r\n", 
            request_line, strhead, host)
    else
        total = string.format("%s%scontent-length:%d\r\n\r\n%s\r\n", 
            request_line, strhead, #form, form)
    end

    send(total)
    shaco.trace("http request send:", total)

    local status, chunk
    status, chunk = statusline(read)
    local code = tonumber(status:match("HTTP/%d+%.%d+%s+(%d%d%d)%s+.*$"))
    shaco.trace("http read code:", code)

    local head_t, tmp_t
    tmp_t, chunk = header(chunk, read)
    head_t = parse_header(tmp_t, {})

    local length = head_t["content-length"]
    if length then
        length = tonumber(length)
    end
    local body
    local mode = head_t["transfer-encoding"]
    shaco.trace("http read header:", tostring(length), tostring(mode))
    if mode then
        if mode == "identity" then
            assert(length, "Not content-length")
            body = content(length, chunk, read) 
            shaco.trace("http content read by mode identity")
        elseif mode == "chunked" then
            body, chunk = chunkbody(chunk, read)
            shaco.trace("http content read by mode chunked")
            tmp_t, chunk = header(chunk, read)
            shaco.trace("http content read by mode chunked, header")
            head_t = parse_header(tmp_t, head_t)
        else
            error("Unsupport transfer-encoding")
        end
    else
        if length then
            --in websocket no this
            --assert(length, "Not content-length")
            body = content(length, chunk, read)
            shaco.trace("http content read by mode none")
        end
    end
    shaco.trace("http read over!")
    return code, body
end

http.request = request

function http.get(host, uri, headers)
    local host, port = host:match("([^:]+):?(%d*)$")
    port = tonumber(port) or 80
    local id = assert(socket.connect(host, port))
    socket.readon(id)
    local code, body
    local ok, err = pcall(function()
        code, body = request("GET", host, uri, headers, nil,
            httpsocket.reader(id),
            httpsocket.sender(id))
        end)
    socket.close(id)
    if not ok then
        error(err)
    end
    return code, body
end

function http.post(host, uri, headers, form)
    local host, port = host:match("([^:]+):?(%d*)$")
    port = tonumber(port) or 80
    shaco.trace("http post:"..host..":"..port)
    local id = assert(socket.connect(host, port))
    shaco.trace("http post:"..host..":"..port.." ok")
    socket.readon(id)
    local code, body
    local ok, err = pcall(function()
        code, body = request("POST", host, uri, headers, form,
            httpsocket.reader(id),
            httpsocket.sender(id))
        end)
    socket.close(id)
    if not ok then
        error(err)
    end
    return code, body
end

function http.read(read)
    local head_t, chunk
    head_t, chunk = header("", read)
    if #head_t == 0 then
        return 400 -- Bad Request
    end
    local request_line = head_t[1]
    local method, uri, version = request_line:match("^(%a+)%s+([^%s]+)%s+HTTP/(%d+%.%d+)")
    if not method or not uri or not version then
        return 400 -- Bad Request
    end
    version = tonumber(version)
    if version < 1.0 or version > 1.1 then
        return 505 -- HTTP Version not supported
    end 
    table.remove(head_t, 1)
    head_t = parse_header(head_t, {})
    local length = head_t["content-length"]
    if length then
        length = tonumber(length)
    end
    local body
    local mode = head_t["transfer-encoding"]
    if mode then
        if mode == "identity" then
            if not length then
                return 411
            end
            body = content(length, chunk, read) 
        elseif mode == "chunked" then
            body = chunkbody(chunk, read)
        else
            return 501
        end
    else
        if length then
            body = content(length, chunk, read) 
        end
    end
    return 200, method, uri, head_t, body, version
end

function http.response(code, body, head_t, send)
    local status_line = string.format("HTTP/1.1 %03d %s\r\n", code, strcode[code] or "")
    send(status_line)
    if head_t then
        for k, v in pairs(head_t) do
            send(string.format("%s: %s\r\n", k,v))
        end
    end
    local t = type(body)
    if t == "string" then
        send(string.format("content-length: %d\r\n\r\n", #body))
        send(body)
    elseif t == "function" then
        send(string.format("transfer-encoding: chunked\r\n"))
        while true do
            local chunk = body()
            if chunk then
                send("\r\n%x\r\n", #chunk)
                send(chunk)
            else
                send("\r\n0\r\n\r\n")
                break
            end
        end
    elseif t == "nil" then
        if unneed_body(code) then
            send("\r\n")
        else
            send(string.format("content-length: 0\r\n\r\n"))
        end
    else
        error("Invalid body type: "..t)
    end
end

return http
