--[[
	run: lua export_keymap.lua
	will generate keymap.lua file, currently it used in libs/inputmgr/keymap.lua
]]
local vnmap = {}

local function read_namecode_from_file(filename, pattern)
	for l in io.lines(filename) do
		local name, code = l:match(pattern)
		if name and code then			
			local CODE = tonumber(code)
			vnmap[CODE] = name
		end	
	end
end

read_namecode_from_file("../../clibs/window/virtual_keys.h", "#define%s+VK_([%w_%d]+)%s+([XxA-Fa-f%d]+)")

local ranges = {{'0', '9'}, {'A', 'Z'}, {'a', 'z'}}
for j=1, #ranges do
	for i=string.byte(ranges[j][1]), string.byte(ranges[j][2]) do 
		local name = string.char(i):upper()
		vnmap[i] = name
	end
end

local function change_name(newname, oldname)
	assert(newname ~= oldname)	
	for k in pairs(vnmap) do
		if k == oldname then
			vnmap[newname] = vnmap[k]
			vnmap[k] = nil
			return
		end
	end
end

change_name("LSYS", "LWIN")
change_name("RSYS", "RWIN")

local sortkeys = {}
for k in pairs(vnmap) do
	table.insert(sortkeys, k)
end
table.sort(sortkeys)

local keymap = io.open("keymap.lua", "w")
keymap:write([[
--using export_keymap.lua to generate this file: lua export_keymap.lua
]])

keymap:write("return {\n")
for _, k in ipairs(sortkeys) do
	local v = vnmap[k]
	keymap:write(string.format("\t[%d] = '%s',\n", k, v))
end
keymap:write("}\n")

keymap:close()
