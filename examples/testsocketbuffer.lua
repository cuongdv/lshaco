local shaco = require "shaco"
local socketbuffer = require "socketbuffer.c"

local sb = socketbuffer.new()

local str = string.char(0x0d)
local data, size = shaco.tobytes(str)
sb:push(data, size)

local s = sb:pop("\r\n")
print(s)

local str = string.char(0x0a, 0x74)
local data, size = shaco.tobytes(str)
sb:push(data, size)

local s= sb:pop("\r\n")
print(s)
