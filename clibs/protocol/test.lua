local core = require "protocol"

local cache = {}

local function assert_result(t1, t2)
	if #t1 ~= #t2 then
		error (string.format("Size = %d %d", #t1, #t2))
	end
	for i, v in ipairs(t1) do
		if v ~= t2[i] then
			error (string.format("%q\n%q",v,t2[i]))
		end
	end
end

local function CHUNK(m, r, t, input)
	assert( core.readchunk(m) == r )
	assert_result(m , t)
	if input then
		assert_result(m, input)
	end
end

CHUNK( { "\0" }, nil , { "\0" } )
CHUNK( { "\0\0" }, "" , {} )
CHUNK( { "\0\0hello" }, "" , { "hello" } )
CHUNK( { "\1\0hello" }, "h" , { "ello" } )
CHUNK( { "\6\0hello" }, nil , { "\6\0hello" } )
CHUNK( { "\5\0", "hello" }, "hello", {})
CHUNK( { "\5", "\0hello" }, "hello", {})
CHUNK( { "", "\5", "\0hello" }, "hello", {})
CHUNK( { "", "\5", "", "", "\0", "h", "ello" }, "hello", {})
CHUNK( { "", "\5", "", "", "\0", "h", "ell" }, nil, {"\5\0hell"} )
CHUNK( { "\5\0", "hello\5", "", "\0" }, "hello", {"\5","", "\0"})
CHUNK( { "\5\0", "hello\0\0" }, "hello", {"\0\0"})
CHUNK( { "\5", "\0hel", "lo\5", "\0" }, "hello", {"\5","\0"})
CHUNK( { "\5", "\0hello\0\0" } , "hello", {"\0\0"})

local temp = {}
for i=0,255 do
	temp[i+1] = (string.char(i)):rep(256)
end

temp[255] = temp[255]:sub(1,255)

local str = table.concat(temp)
CHUNK( { "\xff\xff", table.unpack(temp) } , str, {} )
CHUNK( { "\xff\xff", str:sub(1, -2) }, nil, { "\xff\xff" .. str:sub(1,-2) } )
CHUNK( { "\xfe\xff", str:sub(1, -2) }, str:sub(1,-2), {} )
CHUNK( { "\xfe\xff", str }, str:sub(1,-2), { "\255" } )

local output = {}
local function MESSAGE(m, result)
	local r = core.readmessage(m, output)
	if r == nil then
		assert(result == nil)
	else
		assert_result(r, result)
	end
end

MESSAGE( { "\0\0" }, {} )
MESSAGE( { "\2\0\0\0" }, { "" } )
MESSAGE( { "\7\0\5\0hello" }, { "hello" } )
MESSAGE( { "\14\0\5\0", "hello", "\5\0", "world" }, { "hello", "world" } )
MESSAGE( { "\0" } , nil)
MESSAGE( { "\7", "", "\0\5", "\0", "hell" } , nil, { "\7\0\5\0hell" } )
MESSAGE( { "\7\0\5\0", "hello\0" }, { "hello" } , { "\0" })

local function PACK(m, result)
	local r = core.packmessage(m)
	assert(r == result)
end

PACK( { "hello" }, "\7\0\5\0hello" )
PACK( { "hello" , "world" }, "\14\0\5\0hello\5\0world" )
