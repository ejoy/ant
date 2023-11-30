local zip = require "zip"

local c = zip.compress (("Hello World"):rep(10))
print(#c, c:byte())
print(zip.uncompress(c))


local f = assert(zip.open("test.zip", "w"))

f:add("测试.txt", "测试一下")

f:close()

local f = assert(zip.open("test.zip", "a"))

f:openfile "test.txt"
for i = 1, 1000 do
	f:write "Hello World\n"
end
f:closefile()

f:close()

local f = assert(zip.open("test2.zip", "w"))
f:addfile("test.zip", "test.zip")
f:close()

local f = assert(zip.open("test.zip", "r"))

local list = f:list()
for _, v in ipairs(list) do
	print(v)
end

local c = f:readfile "test.txt"
print(#c)

f:extract("test.txt", "test.txt")

f:openfile "测试.txt"
local c = f:read(6)
print(c)
f:closefile()


local copy = assert(zip.open("test3.zip", "w"))
copy:copyfrom("test.txt", f)

f:close()
copy:close()


local f = assert(zip.open("test.zip", "r"))
local reader = zip.reader(f, 1024* 1024)
local h = {}
for i = 1, 100 do
	h[i] = reader "test.txt"
end
print(zip.reader_dump(reader))
for i = 1, 100 do
	if h[i] then
		print(i, #zip.reader_consume(h[i]))
	end
end
for i = 1, 10 do
	h[i] = reader "test.txt"
end
print(zip.reader_dump(reader))
f:close()

local f = assert(zip.open("test.zip", "r"))
local filename = f:filename "test.txt"
print(filename)
local s1 = f:readfile "test.txt"
local h = zip.reader_open(filename)
local s2 = zip.reader_consume(h)
assert(s1 == s2)
f:close()
