local pb = require "protobuf"
local tbl = require "tbl"
local print = function(...)
    print("[TEST_PB ============================================]", ...)
end

pb.register_file("examples/test.pb")

local function test_ok(decode)
    local mail = {
        data = {
            {mailid=1, mailtype=10},
            {mailid=2, mailtype=20, itemlist={}},
            {mailid=3, mailtype=30, itemlist={{itemid=103, itemname="name103"}}},
        },
        info = { time = 1986, time2 = 1999},
        count = 1000,
        count2= 2000,
    }
    local r
    r = pb.encode("mail_list", mail)
    r = decode("mail_list", r)
    print(tbl(r))
    print(r, r.data, r.info, r.data[1].itemlist, r.data[2].itemlist, r.data[3].itemlist)

    local r
    r = pb.encode("mail_list", mail)
    r = decode("mail_list", r)
    print(tbl(r))
    print(r, r.data, r.info, r.data[1].itemlist, r.data[2].itemlist, r.data[3].itemlist)

end

local function test_error(decode)
    local r
    r = decode("mail_list", "")
    print(r, r.data, r.info)

    r = pb.encode("mail_list", {})
    r = decode("mail_list", r)
    print(r, r.data, r.info)

    r = pb.encode("mail_list", {data={}})
    r = decode("mail_list", r)
    print(r, r.data)

    r = pb.encode("mail_list", {data={{}}})
    r = decode("mail_list", r)
    print(r, r.data, r.info)

    r = pb.encode("mail_list", {data={{}}})
    r = decode("mail_list", r)
    print(r, r.data, r.info)

end

local function test_decode(decode)
    local r
    r = decode("mail_list", "")
    print(r.count)
    print(r.count2)
    print(r.data)
    print(r.info.time)
    for k, v in pairs(r) do
        print(k,v)
    end
    print(r, tbl(r))

    r = pb.encode("mail_list", {})
    r = decode("mail_list", r)
    print(r, tbl(r))

    r = pb.encode("mail_list", {data={}})
    r = decode("mail_list", r)
    print(r, tbl(r))

end

--test_empty()
--print("----------------------------")
--test_normal()
--print("---------------------------- test false")
--test_false()
--test_error(pb.decode)
--test_ok(pb.decode)
print("=========================================")
--test_error(pb.decode)
--test_ok(pb.decode)
test_decode(pb.decode)
os.exit(0)
