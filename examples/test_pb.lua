local pb = require "protobuf"
local tbl = require "tbl"
local print = function(...)
    print("[TEST_PB ============================================]", ...)
end

pb.register_file("examples/test.pb")

local function test_empty()
    local r
    r = assert(pb.decode("mail_list", ""))
    print(r, r.data)

    local mail = {}
    r = pb.encode("mail_list", mail)
    r = pb.decode("mail_list", r)
    print(r, r.data)

    local mail = {data={}}
    local r2 = pb.encode("mail_list", mail)
    r2 = pb.decode("mail_list", r2)
print(tbl(r2, "r"))
    print(r2, r2.data)
    --r2.data[1] = {mailid=10}
    print(r2, r2.data, "----------------")
    print(r2.data[1].mailid)
    print(r.data[1].mailid)

    local mail = {data={}}
    r = pb.encode("mail_list", mail)
    r = pb.decode("mail_list", r)
    print(r, r.data)

    local mail = {data={{}}}
    r = pb.encode("mail_list", mail)
    r = pb.decode("mail_list", r)
    print(r, r.data, r.data[1])--.itemlist)

    local mail = {data={{}}} 
    r = pb.encode("mail_list", mail)
    r = pb.decode("mail_list", r)
    print(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>")
    print(r, r.data, r.data[1])--.itemlist)
end

local function test_normal()
    local r
    local mail = {data={}} 
    r = pb.encode("mail_list", mail)
    r = pb.decode("mail_list", r)
    print(r, r.data)
--    print(tbl(r, "r="))

    local mail = {
        data={
            --{itemlist={{}}}, 
        },
    } 
    r = pb.encode("mail_list", mail)
    print ("===========================================")
    r = pb.decode("mail_list", r)
    print ("===========================================")
    print(r.count)
    print(r.count2)
    print(r, r.data)
    --print(r, r.data)
    ----print(tbl(r, "r="))
    ----print(r.data[1].mailid, r.data[1].mailtype)
    --print(r.count, r.kk1, r.str2)
    --print(r.data[1], r.data[2], r.data[3])
    --print("++++++++++++++++++++++++++++++++++++++")
    --print(r.data[1].mailid)
end

local function test_false()
    local r
    local mail = {data={}} 
    r = pb.encode("mail_list", mail)
    r = pb.decode("mail_list", r)
    print(r, r.data)

    r = pb.encode("mail_list", r)
    r = pb.decode("mail_list", r)
    print(r, r.data)
    r.data = r.data or {}

    r = pb.encode("mail_list", r)
    r = pb.decode("mail_list", r)
    print(r, r.data)
    r.data = r.data or {}
    r.data[1] = {}

    print(tbl(r))

    r = pb.encode("mail_list", r)
    r = pb.decode("mail_list", r)
    print(r, r.data, r.data[1])

    local mail = {data={{}}} 
    r = pb.encode("mail_list", mail)
    r = pb.decode("mail_list", r)
    print(r, r.data, r.data[1].itemlist)

end

local function test_ok()
    local r
    r = pb.decode("mail_list", "")
    print(r, r.data)

    r = pb.encode("mail_list", {})
    r = pb.decode("mail_list", r)
    print(r, r.data)

    r = pb.encode("mail_list", {data={}})
    r = pb.decode("mail_list", r)
    print(r, r.data, r.data[1])

    r = pb.encode("mail_list", {data={{}}})
    r = pb.decode("mail_list", r)
    print(r, r.data, r.data[1])

end

--test_empty()
--print("----------------------------")
--test_normal()
--print("---------------------------- test false")
--test_false()
test_ok()
os.exit(0)
