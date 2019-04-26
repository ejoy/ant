local relate_path = "packages/modelloader/glb"
package.path = package.path .. ";" .. relate_path .. "/?.lua"

local glb = require "glb"
local json = require "json"
local stringify = require "stringify"
local _, jsonData, binData = glb.decode(relate_path .. "/Bee.glb")
local t = json.decode(jsonData)

local function savefile(filename, data)
    local f = assert(io.open(filename, "w"))
    f:write(data)
    f:close()
end
local luaData = stringify(t, true)

savefile(relate_path .. "/test-bee.lua", luaData)
savefile(relate_path .. "/test-bee.json", jsonData)
savefile(relate_path .. "/test-bee.bin", binData)

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
