local memfs = import_package "ant.vfs".memory

memfs.init()

local vfs = require "vfs"
local fastio = require "fastio"

local f = assert(io.open("testmem.txt", "wb"))
local content = "Hello World"

f:write(content)
f:close()

memfs.update("/pkg/testmem/test.txt", "testmem.txt")

local c = vfs.read "/pkg/testmem/test.txt"
local s = fastio.tostring(c)
print(s)
assert(s == content)


local fs = require "filesystem"
for d in fs.pairs("/pkg") do
	print("dir", d)
	if d:string() == "/pkg/testmem" then
		for file in fs.pairs(d) do
			print("\tfile ", file)
		end
	end
end
