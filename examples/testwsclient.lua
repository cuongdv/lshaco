local shaco = require "shaco"
local websocket = require "websocket"

shaco.start(function()
    local id = assert(websocket.connect("127.0.0.1:448", "/", {origin="http://127.0.0.1"}))
    print ("connect ok: "..id)
    local ok, err = xpcall(function()
        print ('EnterBorder ...')
        websocket.send(id, string.pack("<BI4", 255, 0))
        while true do
            local border, data2 = websocket.read(id)
            local msgid = string.unpack("<B", border)
            print ("RECV: ", msgid..":"..#border)
        end
        local msgid, left, top, right, bottom = string.unpack("<Bi4i4i4i4", border)
        assert(msgid == 64)
        print ('SetBorder:', left, top, right, bottom)
    end, debug.traceback)
    if not ok then
        print (err)
    end
    websocket.close(id)
end)
