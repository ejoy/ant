local relate_path = "packages/glTF"
package.path = package.path .. ";" .. relate_path .. "/?.lua"

local glb = require "glb"
local json = require "json"
local stringify = require "stringify"
local glbData = glb.decode(relate_path .. "/test_resources/Bee.glb")

local function savefile(filename, data)
    local f = assert(io.open(filename, "w"))
    f:write(data)
    f:close()
end
local luaData = stringify(glbData.info, true)

savefile(relate_path .. "/test_resources/test-bee.lua", luaData)
savefile(relate_path .. "/test_resources/test-bee.json", json.encode(glbData.info))
savefile(relate_path .. "/test_resources/test-bee.bin", glbData.bin)
glb.encode(relate_path .. "/test_resources/test-bee.glb", glbData)

local function EQUAL(a, b)
	for k, v in pairs(a) do
		if type(v) == 'table' then
			EQUAL(v, b[k])
		else
			assert(v == b[k])
		end
	end
end

EQUAL(assert(load(luaData))(), glbData.info)

print("ok")
