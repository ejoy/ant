--[[
	run: lua export_keymap.lua
	will generate keymap.lua file, currently it used in libs/inputmgr/keymap.lua
]]
local nvmap = {}
local vnmap = {}

local function read_namecode_from_file(filename, pattern)
	for l in io.lines(filename) do
		local name, code = l:match(pattern)
		if name and code then			
			local CODE = tonumber(code)
			nvmap[name] = CODE
			vnmap[CODE] = name
		end	
	end
end

read_namecode_from_file("WinUser.h", "#define%s+VK_([%w_%d]+)%s+([XxA-Fa-f%d]+)")
-- iupkey.h must after WinUser.h for asii code correct
read_namecode_from_file("iupkey.h", "#define%s+K_[%w]+%s+'([^']+'?)'%s*/%*%s*([^ ]+).+")


local ranges = {'0', '9', 'A', 'Z',}
for j=1, #ranges, 2 do
	for i=string.byte(ranges[j+0]), string.byte(ranges[j+1]) do 
		local name = string.char(i)
		nvmap[name] = i
		vnmap[i] = name 
	end
end

local function change_name(newname, oldname)
	nvmap[newname] = assert(nvmap[oldname])	
	vnmap[nvmap[newname]] = newname
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

keymap:write("local codename_mapper = {\n")
for _, k in ipairs(sortkeys) do
	local v = vnmap[k]
	keymap:write(string.format("\t[%d] = '%s',\n", k, v))
end
keymap:write("}\n\n")

local sortnames = {}
for k in pairs(nvmap) do
	table.insert(sortnames, k)
end

table.sort(sortnames)

keymap:write("local namecode_mapper = {\n")
for _, k in pairs(sortnames) do
	local v = nvmap[k]
	keymap:write(string.format("\t['%s'] = %d,\n", k, v))
end
keymap:write("}\n")

keymap:write([[
local util = {}; util.__index = util
function util.name(code)
	return codename_mapper[code]
end
function util.code(name)
	return namecode_mapper[name]
end
return util
]])

keymap:close()