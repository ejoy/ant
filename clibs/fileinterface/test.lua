local fileinterface = require "fileinterface"
local test = require "fileinterface.test"

local function preopen(filename)
	print("Open", filename)
	return filename
end

local factory = fileinterface.factory { preopen = preopen }

local f = test.open(factory, "test.lua", "r")
local s = f:read(100)
print(s)
f:close()