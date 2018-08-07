local toolset = require "editor.toolset"

local assetmgr = require "asset"
local fs = require "filesystem"
local fu = require "filesystem.util"

local path = require "filesystem.path"
local shader_mgr = require "render.resources.shader_mgr"

--local fs =  require "cppfs"

local function compile_shader(filename, outfilename)
    local config = toolset.load_config()
	if next(config) then
		local cwd = fs.currentdir()
		config.includes = {config.shaderinc, cwd .. "/assets/shaders/src"}
        config.dest = outfilename
		return toolset.compile(filename, config, shader_mgr.get_compile_renderer_name())
	end
	
	return nil, "config is empty, try run libs/lua/lua.exe config.lua"
end

local shader_srcsubpath = "shaders/src"

local function gen_cache_path(srcpath)	
	local rt_path = shader_mgr.get_shader_rendertype_path()
	assert(#srcpath > #shader_srcsubpath)
	local relative_path = path.replace_ext(srcpath:sub(#shader_srcsubpath+1), "bin")	
	return "cache/shaders/" .. rt_path .. relative_path
end

local function check_compile_shader(srcpath)
	assert(srcpath:sub(1, #shader_srcsubpath) == shader_srcsubpath)

    assert(path.ext(srcpath):lower() == "sc")
	local asset_srcpath = assetmgr.find_valid_asset_path(srcpath)
	if asset_srcpath then		
		local outfile = gen_cache_path(srcpath)
		path.create_dirs(path.parent(outfile))
		local success, msg = compile_shader(asset_srcpath, outfile)
		if not success then
			print(string.format("try compile from file: %s to file: %s , \
			but failed, error message : \n%s", asset_srcpath, outfile, msg))
			return nil
		end
		return outfile
	end

	print(asset_srcpath .. ", not found in assets folder")
	return nil
end

return function (lnk, readmode)
	local c = assetmgr.load(lnk)	
	local src = assert(c.shader_src)

	local cache_path = gen_cache_path(src)
	
	if not fs.exist(cache_path) or 
		fu.file_is_newer(lnk, cache_path) then
		local outfile = check_compile_shader(src)		
		assert(outfile == cache_path)		
	end

	return io.open(cache_path, readmode)
end