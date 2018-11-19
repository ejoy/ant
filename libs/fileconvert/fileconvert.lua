local fs = require "filesystem"
local path = require "filesystem.path"
local rawtable = require "common.rawtable"
local rules = {}

local cfgcontent = rawtable("config/fileconvert.cfg")
local rulescfg = cfgcontent.rules
for _, line in ipairs(rulescfg) do
	local t = {}
	for m in line:gmatch("[^%s]+") do
		table.insert(t, m)
	end

	local pattern, convertor_path, reg = t[1], t[2], t[3]
	if pattern then	
		if reg == nil then
			pattern = pattern:gsub('[%^%$%(%)%%%.%[%]%+%-%?]', '%%%0'):gsub('%*', '.*')
		end

		local convertor = require(convertor_path)
	
		table.insert(rules, { pattern=pattern, convertor=convertor })
	end
end
	

local function glob_match(pattern, target)
    return target:match(pattern) ~= nil
end

-- TODO: need pass from outside
local shadertype = "d3d11"

local function find_convertor(path)	
    for _, p in pairs(rules) do
		if glob_match(p.pattern, path) then
			local convertor = p.convertor
			if path:match "%.sc$" then
				return function()
					convertor(path, shadertype)
				end
			end
			return convertor
        end
    end
end

local fileconvertor = {}

function fileconvertor.log(fmt)
end

local function mesh_filter(absdir, files)
	path.listfiles(absdir, files, {"bin", "fbx"})
end

local filefetchers = {
	["shaders/src"] = function (absdir, files)
		path.listfiles(absdir, files,
		function (filepath) 
			local ext = path.ext(filepath)
			if ext == "sc" then
				return not filepath:match("%.def%.sc")
			end
		end)	
	end,
	["meshes"] = mesh_filter,
	["build/meshes"] = mesh_filter,
}

local function convertor(absdir)
	local convertor = find_convertor(absdir)
	if convertor then		
		convertor(absdir)
	end
end

function fileconvertor.convert_dir(srcdir)
	srcdir = srcdir or (fs.currentdir() .. "/assets")

	local files = {}
	for subdir, fetcher in pairs(filefetchers) do
		fetcher(path.join(srcdir, subdir), files)
	end

	for _, ff in ipairs(files) do
		convertor(ff)
	end
end

function fileconvertor.convert_file(absdir)
	convertor(absdir)
end

local watch_files = {}
function fileconvertor.watch_file(file)
	local f = file:gsub("(.+)/$", "%1")

	if watch_files[f] == nil and 
		find_convertor(f) then
		watch_files[f] = true
	end
end

function fileconvertor.convert_watchfiles()
	for f in pairs(watch_files) do
		convertor(f)
	end
	watch_files = {}
end

return fileconvertor

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
