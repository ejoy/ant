local toolset = require "editor.toolset"
local path = require "filesystem.path"
local fu = require "filesystem.util"
local vfs = require "vfs"

local config = require "common.config"

local platform = config.platform()

local function compile_shader(filename, outfilename, shadertype)
    local config = toolset.load_config()
	if next(config) then		
		local engineshaderpath = vfs.realpath("engine/assets/shaders/src")
		config.includes = {config.shaderinc, engineshaderpath}
        config.dest = outfilename
		return toolset.compile(filename, config, shadertype, platform)
	end
	
	return nil, "config is empty, try run clibs/lua/lua.exe config.lua"
end

local function check_compile_shader(srcpath, outfile, shadertype)	
	fu.create_dirs(path.parent(outfile))	
	local success, msg = compile_shader(srcpath, outfile, shadertype)
	if not success then
		return nil, msg
	end
	return outfile, nil
end

return function (plat, sourcefile, param, outfile)
	local shadertype = param.shadertype
	if shadertype == nil then
		local rhwi = require "render.hardware_interface"
		shadertype = rhwi.shader_type()
		if shadertype == nil then
			shadertype = rhwi.default_shader_type(plat)
		end		
	end
	local binfile, error = check_compile_shader(sourcefile, outfile, shadertype)
	if error then
		return nil, error
	end

	return true
end
