local datalist = require "datalist"

local function keys(a)
	local key = {}
	for k in pairs(a) do
		key[#key + 1] = k
	end
	return key
end

local function compare_table(a,b)
	if type(a) ~= "table" then
		assert(a == b)
	else
		local k = keys(a)
		assert(#k == #keys(b))
		for k,v in pairs(a) do
			local v2 = b[k]
			compare_table(v, v2)
		end
	end
end

local function C(str)
	local t = datalist.parse(str)
	return function (tbl)
		local ok , err = pcall(compare_table , t, tbl)
		if not ok then
			print("Error in :")
			print(str)
			for k,v in pairs(t) do
				print(k,v, type(v))
			end
			error(err)
		end
	end
end

local function F(str)
	local ok = pcall(datalist.parse, str)
	assert(not ok)
end

C [[
---
x : 1
y : 2
---
---
b : 2
---
hello
world
--- { 1,2,3 }
---
	---
	x : 1
	---
	y : 2
]] {
	{ x = 1 , y = 2 },
	{},
	{ b = 2 },
	{ "hello", "world" },
	{ 1,2,3 },
	{ { x = 1 } , { y = 2 } },
}

C [[
a :
	- 1
	- 2
	- 3
b :
	-1
	2
	3
c :
	---
	x = 1
	---
	y = 2
]] {
	a = { 1,2,3 },
	b = { -1,2,3 },
	c = { { x = 1 }, { y = 2 } },
}

C [[
hello "world"
"newline\n"
]] {
	"hello",
	"world",
	"newline\n",
}


C [[
list :
	1,2
	3,4
x = 1 y = 2.0
layer :
	a = hello
	b = world
z = 0x3
w = {1,2,3}
map = { x = 1, y =
	{ a , b, c }
}
]] {
	list = { 1,2,3,4 },
	x = 1,
	y = 2,
	z = 3,
	layer = {
		a = "hello",
		b = "world",
	},
	w = { 1,2,3 },
	map = { x = 1, y = { "a", "b", "c" } }
}

local mt = { __newindex = function (t,k,v)
	rawset(t,k,v)
	print("SET", k, v)
end }

datalist.parse("x=1,y=2", setmetatable({}, mt))

local token = datalist.token [[
first
	hello world  # comment
---
	1
	2
"hello world"
]]

for _,v in ipairs(token) do
	print(string.format("[%s]",v))
end