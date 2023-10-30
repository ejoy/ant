package.path = "engine/?.lua;?.lua"
require "bootstrap"

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

f:openfile "测试.txt"
local c = f:read(6)
print(c)
f:closefile()

f:close()
