local toolset = require "editor.toolset"
local path = require "filesystem.path"
local fu = require "filesystem.util"
local fs = require "filesystem"

local function compile_shader(filename, outfilename, shadertype)
    local config = toolset.load_config()
	if next(config) then
		
		config.includes = {config.shaderinc, fs.currentdir() .. "/assets/shaders/src"}
        config.dest = outfilename
		return toolset.compile(filename, config, shadertype)
	end
	
	return nil, "config is empty, try run clibs/lua/lua.exe config.lua"
end

local function gen_output_path(srcpath, shadertype)
	assert(path.ext(srcpath):lower() == "sc")
	
	local dstpath, subnum = srcpath:gsub("(.+[/\\]shaders[/\\])src(.+)%.sc", "%1" .. shadertype .. "%2.bin")
	if subnum == 0 then
		local filename = path.replace_ext(path.filename(srcpath), "bin")
		return path.join(path.parent(srcpath), shadertype, filename)
	end
	return dstpath	
end

local function check_compile_shader(srcpath, outfile, shadertype)	
	path.create_dirs(path.parent(outfile))	
	local success, msg = compile_shader(srcpath, outfile, shadertype)
	if not success then
		return nil, msg
	end
	return outfile, nil
end


return function(filepath, shadertype)
	local dstpath = gen_output_path(filepath, shadertype)
	
	if fu.file_is_newer(filepath, dstpath) then
		local outfile, error = check_compile_shader(filepath, dstpath, shadertype)
		if error then
			return nil, error
		end
		assert(outfile == dstpath)
	end

	return dstpath
end
