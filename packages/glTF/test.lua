local relate_path = "packages/glTF"
package.path = relate_path .. "/?.lua"

local function savefile(filename, data)
	local f = assert(io.open(filename, "wb"))
	f:write(data)
	f:close()
end

local glb = require "glb"
local json = require "json"
local glbData = glb.decode(relate_path .. "/test_resources/Bee.glb")

savefile(relate_path .. "/test_resources/test-bee.json", json.encode(glbData.info))
savefile(relate_path .. "/test_resources/test-bee.bin", glbData.bin)
glb.encode(relate_path .. "/test_resources/test-bee.glb", glbData)

local function EQUAL_1(a, b)
	for k, v in pairs(a) do
		if type(v) == 'table' then
			EQUAL_1(v, b[k])
		else
			assert(v == b[k])
		end
	end
end

local function EQUAL(a, b)
	EQUAL_1(a, b)
	EQUAL_1(b, a)
end

local newGlbData = glb.decode(relate_path .. "/test_resources/test-bee.glb")
EQUAL(newGlbData.info, glbData.info)

print("ok")
