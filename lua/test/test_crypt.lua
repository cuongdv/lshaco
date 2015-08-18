local shaco = require "shaco"
local crypt = require "crypt.c"

shaco.start(function()
    local rsai = crypt.rsa_new("./rsakey0.pem", false)
    local rsap = crypt.rsa_new("./rsakey0.pub", true)

    local s = "1234567890"
    local s_in = s
    print (">", s_in)
    s_in = rsai:private_encrypt(s_in)
    --print (">", s_in)
    s_in = crypt.base64encode(s_in)
    print (">", s_in)

    s_in = crypt.base64decode(s_in)
    --print ("<", s_in)
    s_in = rsap:public_decrypt(s_in)
    print ("<", s_in)

    assert(s==s_in)
end)
