local shaco = require "shaco"
local mysql = require "mysql"
local tbl = require "tbl"

local Z = string.char(0x1a)
local function escape_string(s)
    return "'"..
    string.gsub(s, ".", function(c) 
        if c == '\0' then
            return '\\0'
        elseif c == '\'' then
            return '\\\''
        elseif c == '\"' then
            return '\\"'
        elseif c == '\b' then
            return '\\b'
        elseif c == '\n' then
            return '\\n'
        elseif c == '\r' then
            return '\\r'
        elseif c == '\t' then
            return '\\t'
        elseif c == Z then
            return '\\Z'
        elseif c == '\\' then
            return '\\\\'
        end
    end).."'"
end

local ESCAPE = {
    ['\0'] = '\\0',
    ['\''] = '\\\'',
    ['\"'] = '\\"',
    ['\b'] = '\\b',
    ['\n'] = '\\n',
    ['\r'] = '\\r',
    ['\t'] = '\\t',
    [string.char(0x1a)]    = '\\Z',
    ['\\'] = '\\\\',
}

local function escape_string2(s)
    return "'"..string.gsub(s, ".", ESCAPE).."'"
end

local function ping(my, id)
    while true do
        local ok , err = pcall(my.ping, my)
        if ok then
            print ("ping:"..id)
            shaco.sleep(500)
        else
            print ("disconnect:", err)
            shaco.sleep(500)
        end
    end
end

local function statistics(my, id)
    while true do
        print("statistics:"..id, my:statistics())
        shaco.sleep(500)
    end
end

local function processinfo(my, id)
    while true do
        local result = my:processinfo()
        print ("processinfo:"..id, result)
        shaco.sleep(500)
    end
end

local function test1(my)
    assert(my:use("lxj"))
    print ("use lxj ok")
    print("[statistics]"..my:statistics())
    local result = my:processinfo()
    tbl.print(result, "processinfo")

    local result = my:execute("insert into x_role (name, acc, base) values('test_name', 'test_acc', '')")
    tbl.print(result, "execute")

    local result = my:execute("update x_role set base='1', info='' where name='test_name'")
    tbl.print(result, "execute")

    local result = my:execute("select roleid, acc, name from x_role where name='test_name' limit 2")
    tbl.print(result, "execute")

    --print(my.escape_string(""))

    --print(my.escape_string("\\\0\'\"\b\n\r\t"))
    --print(escape_string("\\\0\'\"\b\n\r\t"))
    --print(escape_string2("\\\0\'\"\b\n\r\t"..string.char(0x1a)))

    --local t1, t2

    --t1 = shaco.time()
    --for i=1,100000 do
        --my.escape_string("\\\0\'\"\b\n\r\t")
    --end
    --t2 = shaco.time()
    --print("------------ time", t2-t1)

    --t1 = shaco.time()
    --for i=1,100000 do
        --escape_string("\\\0\'\"\b\n\r\t")
    --end
    --t2 = shaco.time()
    --print("------------ time", t2-t1)

    --t1 = shaco.time()
    --for i=1,100000 do
        --escape_string2("\\\0\'\"\b\n\r\t")
    --end
    --t2 = shaco.time()
    --print("------------ time", t2-t1)
end

shaco.start(function()
    local my = assert(mysql.connect{
        host = "127.0.0.1",
        port = 3306,
        user = "lxj",
        passwd = "123456",
        db = "lxj",
    })

    --shaco.fork(ping, my, 1)
    --shaco.fork(ping, my, 2)
    --shaco.fork(ping, my, 3)
    
    shaco.fork(ping, my, 1)
    shaco.fork(statistics, my, 1)
    shaco.fork(processinfo, my, 1)
    shaco.fork(test1, my)

end)
