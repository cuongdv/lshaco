local shaco = require "shaco"
local crypt = require "crypt.c"
shaco.start(function()
    shaco.debug("Hello World")
    shaco.trace("Hello World")
    shaco.warn("Hello World")
    shaco.error("Hello World")
    local key = "MTMtMTQ2MzI5NzcwMjU5Nw=="
    print(crypt.base64encode(
        crypt.sha1(key.."258EAFA5-E914-47DA-95CA-C5AB0DC85B11")))
end)
