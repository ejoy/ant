local fs = require "filesystem"
local path = require "filesystem.path"
-- local rules = {}

-- do
-- 	local f = io.open("config/fileconvert.cfg")
-- 	for line in f:lines() do
-- 		local t = {}
-- 		for m in line:gmatch("[^%s]+") do
-- 			table.insert(t, m)
-- 		end

-- 		local pattern, convertor, reg = t[1], t[2], t[3]
-- 		if pattern then	
-- 			if reg == nil then
-- 				pattern = pattern:gsub('[%^%$%(%)%%%.%[%]%+%-%?]', '%%%0'):gsub('%*', '.*')
-- 			end
-- 			table.insert(rules, { pattern, convertor })
-- 		end
-- 	end
-- end	
	

-- local function glob_match(pattern, target)
--     return target:match(pattern) ~= nil
-- end

-- local function find_convertor(path)	
--     for _, rule in ipairs(rules) do
--         if glob_match(rule[1], path) then
--             return rule[2]
--         end
--     end
-- end

local function filter_files(absdir, exts)	
	
	local files = {}	
	path.listfiles(absdir, files, exts)	
	return files
end

local function mesh_filter(absdir)
	local files = filter_files(absdir, {"bin", "fbx"})
	local convertor = require "fileconvert.convertmesh"
	for _, f in ipairs(files) do
		convertor(f)
	end
end

local shadertype = "d3d11"

local convertors = {
	["shaders/src"] = function (absdir)
		local files = filter_files(absdir, function (filepath) 
			local ext = path.ext(filepath)
			if ext == "sc" then
				return not filepath:match("%.def%.sc")
			end
		end)
		local convertor = require "fileconvert.compileshadersource"
		for _, f in ipairs(files) do
			convertor(f, shadertype)
		end
	end,
	["meshes"] = mesh_filter,
	["build/meshes"] = mesh_filter,
}

return function(srcdir)
	srcdir = srcdir or (fs.currentdir() .. "/assets")

	for subdir, convertor in pairs(convertors) do
		convertor(path.join(srcdir, subdir))
	end
end

-- return function (filepath)
-- 	assert(path.is_absolute_path(filepath))
-- 	if path.isdir(filepath) then
-- 		return filepath, false
-- 	end

--     local convertorpath = find_convertor(filepath)
-- 	if not convertorpath then		
-- 		error(string.format("not found file convertor from file:%s", filepath))
-- 		return filepath, false
-- 	end

-- 	local convertor = require(convertorpath)
-- 	return convertor(filepath), true
-- end
