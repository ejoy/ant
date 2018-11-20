local fs = require "lfs"
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

local logfile = nil
if cfgcontent.logfile then
	local logfilepath = cfgcontent.logfile
	path.create_dirs(path.parent(logfilepath))
	logfile = io.open(logfilepath, "w")
elseif cfgcontent.debug_print then
	logfile = io.stdout
end

local shadertypes = assert(cfgcontent.shader).types or {"d3d11", }

local function log(fmt, ...)
	if logfile then
		assert(select('#', ...) == 2)
		local ffff = string.format(fmt, ...)
		logfile:write(ffff)
		logfile:write("\n")
	end
end
	

local function glob_match(pattern, target)
    return target:match(pattern) ~= nil
end

local function find_convertor(filepath)	
    for _, p in pairs(rules) do
		if glob_match(p.pattern, filepath) then
			local convertor = p.convertor
			if filepath:match "%.sc$" then
				return function()
					local loginfo = nil
					local newfiles = {}
					for _, st in ipairs(shadertypes) do
						local outfile, err = convertor(filepath, st)
						if err then
							if loginfo == nil then
								loginfo = {}
							end
							table.insert(loginfo, string.format("shadertype:%s, error:%s", st, err))
						else
							table.insert(newfiles, outfile)
						end
					end

					return newfiles, loginfo and table.concat(loginfo, "\n") or nil
				end
			end
			return convertor
        end
    end
end

local fileconvertor = {}

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
	local c = find_convertor(absdir)
	if c then		
		local outfile, err = c(absdir)
		if err then
			log("from source:%s, error:%s", absdir, err)
			print("warning:", absdir,  "convert failed!")
		end
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
