local memfs = import_package "ant.vfs".memory

memfs.init()

local vfs = require "vfs"
local fastio = require "fastio"

local f = assert(io.open("testmem.txt", "wb"))
local content = "Hello World"

f:write(content)
f:close()

memfs.update("/testmem/test.txt", "testmem.txt")

local c = vfs.read "/testmem/test.txt"
local s = fastio.tostring(c)
print(s)
assert(s == content)
