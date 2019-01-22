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

local mt = { __newindex = function (t,k,v)
	rawset(t,k,v)
	print("SET", k, v)
end }

--datalist.parse("x=1,y=2", setmetatable({}, mt))

C [[
[]
{{}},
hello
]] {{}, {{}}, "hello"}

C [[
a=1	-- comment
b=2.0
c=0x3
d=0x1p+0
e={}
]] {
	a = 1,
	b = 2.0,
	c = 3,
	d = 0x1p+0,
	e = {},
}

C [[
a:0xff
b:1.2345
]] {
	a = 0xff,
	b = 1.2345,
}

C [[
a="hello world"
汉字=汉字
]] {
	a = "hello world",
	["汉字"] = "汉字",
}

C [[
1
2
3
nil
true
false
on,
off,
yes,
no,
]] { 1,2,3,nil,true,false,true,false,true,false }

C [[
"hello\nworld",
"\0\1\2\3\4\xff",
]] {
	"hello\nworld",
	"\0\1\2\3\4\xff",
}

C [[
{ 1,2,3 }
]] {
	{ 1, 2, 3 }
}

C [[
a = { 1,2,3 }
]] {
	a = { 1,2,3 }
}

C [[
[ a = 1, b = "hello" ]
{ c = 2 }
3
]] {
	{ "a" , 1 , "b", "hello" },
	{ c = 2 },
	3,
}



C [[
##XXX
hello
##YYY
x = 1
y = 2
###YYY : 3	-- single value section
z = 4
**ZZZ
a = 1
b = 2
***EMPTY
***WWW
array
{ 1,2,3,4 }
]] {
	XXX = { "hello" },
	YYY = {
		x = 1,
		y = 2,
		YYY = 3,
		z = 4,
	},
	ZZZ = { "a", 1, "b", 2, "EMPTY", {}, "WWW", {"array", {1,2,3,4}} },
}


F [[
"a" : hello
]]

F [[
a
b:1
]]