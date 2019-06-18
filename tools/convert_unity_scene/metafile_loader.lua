
-- package.path = "libs/?.lua;libs/?/?.lua"
-- package.cpath = "projects/msvc/vs_bin/x64/Debug/?.dll"
local fs = require "filesystem.local"

local function loader(filepath)
	local f = fs.open(filepath, "r")
	
	local content = {}
	local cur_node = content
	local parents = {}
	local cur_level = ''
	for l in f:lines() do
		local level, key, value = l:match "(%s*)(.+):(.*)$"
		local newlevel_num = #level
		local oldlevel_num = #cur_level

		local delta = newlevel_num - oldlevel_num
		if delta == -2 then
			cur_node = parents[#parents]
			table.remove(parents)
		end
			
		cur_level = level
		if value == nil or value == "" then
			table.insert(parents, cur_node)
			local children = {}
			cur_node[key] = children
			cur_node = children
		else
			local num = tonumber(value)
			if num then
				cur_node[key] = num
			else 
				local listvalue = value:match "%s*%[(.+)%]"
				if listvalue then
					local vv = {}
					for v in listvalue:gmatch "([^,])" do
						vv[#vv+1] = v
					end
					cur_node[key] = vv
				else
					cur_node[key] = value
				end
			end
		end
	end

	f:close()

	return content
end

--loader(fs.path "D:/Code/github/Viking-Village/Assets/Models/Terrain/terrain_01.fbx.meta")

return loader