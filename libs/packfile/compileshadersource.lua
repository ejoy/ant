local toolset = require "editor.toolset"

local assetmgr = require "asset"
local fs = require "filesystem"
local fu = require "filesystem.util"

local path = require "filesystem.path"
local shader_mgr = require "render.resources.shader_mgr"
local winfile = require "winfile"
local rawopen = winfile.open or io.open

--local fs =  require "cppfs"

local function compile_shader(filename, outfilename)
    local config = toolset.load_config()
	if next(config) then
		local cwd = fs.currentdir()
		config.includes = {config.shaderinc, cwd .. "/assets/shaders/src"}
        config.dest = outfilename
		return toolset.compile(filename, config, shader_mgr.get_compile_renderer_name())
	end
	
	return nil, "config is empty, try run clibs/lua/lua.exe config.lua"
end

local shader_srcsubpath = "shaders/src"

local function gen_cache_path(srcpath)	
	local rt_path = shader_mgr.get_shader_rendertype_path()
	assert(#srcpath > #shader_srcsubpath)
	local subloc = srcpath:find(shader_srcsubpath, 1, true)
	local relative_path = path.replace_ext(srcpath:sub(subloc + #shader_srcsubpath + 1), "bin")	
	return path.join("cache/shaders/" .. rt_path, relative_path)
end

local function check_compile_shader(srcpath)
	assert(srcpath:find(shader_srcsubpath, 1, true))
    assert(path.ext(srcpath):lower() == "sc")
	
	local outfile = gen_cache_path(srcpath)
	path.create_dirs(path.parent(outfile))
	local success, msg = compile_shader(srcpath, outfile)
	if not success then
		print(string.format("try compile from file: %s to file: %s , \
		but failed, error message : \n%s", srcpath, outfile, msg))
		return nil
	end
	return outfile
end

return function (lk, readmode)
	local c = assetmgr.load(lk)
	local src = assetmgr.find_valid_asset_path(assert(c.shader_src))
	if src == nil then
		print(src .. ", not found in assets folder")
		return nil
	end

	local cache_path = gen_cache_path(src)
	
	if fu.file_is_newer(src, cache_path) then
		local outfile = check_compile_shader(src)		
		assert(outfile == cache_path)		
	end

	return rawopen(cache_path, readmode)
end