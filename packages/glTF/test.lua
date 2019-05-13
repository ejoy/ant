local relate_path = "packages/glTF"
package.path = package.path .. ";" .. relate_path .. "/?.lua"

local glb = require "glb"
local json = require "json"
local stringify = require "stringify"
local _, jsonData, binData = glb.decode(relate_path .. "/test_resources/test_glb.glb")
local _, jsonData1, binData1 = glb.decode(relate_path .. "/test_resources/BoxTextured.glb")
local t = json.decode(jsonData)
local t1 = json.decode(jsonData1)

local function savefile(filename, data)
    local f = assert(io.open(filename, "w"))
    f:write(data)
    f:close()
end

savefile(relate_path .. "/test_resources/0.json", jsonData)
savefile(relate_path .. "/test_resources/1.json", jsonData1)

local luaData = stringify(t, true)

savefile(relate_path .. "/test_resources/test-bee.lua", luaData)
savefile(relate_path .. "/test_resources/test-bee.json", jsonData)
savefile(relate_path .. "/test_resources/test-bee.bin", binData)

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
