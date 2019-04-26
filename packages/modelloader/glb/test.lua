local glb = require "glb"
local json = require "json"
local stringify = require "stringify"
local _, jsonData, binData = glb.decode "Bee.glb"
local t = json.decode(jsonData)

local function savefile(filename, data)
    local f = assert(io.open(filename, "w"))
    f:write(data)
    f:close()
end
local luaData = stringify(t, true)

savefile("test-bee.lua", luaData)
savefile("test-bee.json", jsonData)
savefile("test-bee.bin", binData)

local function EQUAL(a, b)
	for k, v in pairs(a) do
		if type(v) == 'table' then
			EQUAL(v, b[k])
		else
			assert(v == b[k])
		end
	end
end

EQUAL(assert(load(luaData))(), t)

print("ok")
