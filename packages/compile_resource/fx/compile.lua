local toolset 	= require "fx.toolset"
local lfs 		= require "filesystem.local"
local stringify = import_package "ant.serialize".stringify
local fs_local  = import_package "ant.utility".fs_local

local engine_shader_srcpath = lfs.current_path() / "packages/resources/shaders"

local valid_shader_stage = {
	"vs", "fs", "cs"
}

local function add_macros_from_surface_setting(mysetting, surfacetype, macros)
	macros = macros or {}

	if surfacetype.lighting == "on" then
		macros[#macros+1] = "ENABLE_LIGHTING"
	end

	local shadow = surfacetype.shadow
	if shadow.receive == "on" then
		macros[#macros+1] = "ENABLE_SHADOW"
	end

	local skinning = surfacetype.skinning
	if skinning.type == "GPU" then
		macros[#macros+1] = "GPU_SKINNING"
	end

	if mysetting.graphic.shadow.type == "linear" then
		macros[#macros+1] = "SM_LINEAR"
	end

	if mysetting.graphic.postprocess.bloom.enable then
		macros[#macros+1] = "BLOOM_ENABLE"
	end

	if mysetting.graphic.compile then
		local compile_macros = mysetting.graphic.compile.macros
		if compile_macros and #compile_macros > 0 then
			table.move(compile_macros, 1, #compile_macros, 1, macros)
		end
	end

	macros[#macros+1] = "ENABLE_SRGB_TEXTURE"
	macros[#macros+1] = "ENABLE_SRGB_FB"
	
	return macros
end

local function load_surface_type(fxcontent)
	local def_surface_type = {
		lighting = "on",			-- "on"/"off"
		transparency = "opaticy",	-- "opaticy"/"translucent"
		shadow	= {
			cast = "on",			-- "on"/"off"
			receive = "off",			-- "on"/"off"
		},
		skinning = {
			type = "UNKNOWN",
		},
		subsurface = "off",			-- "on"/"off"? maybe has other setting
	}
	if fxcontent.surface_type == nil then
		fxcontent.surface_type = def_surface_type
		return
	end
	for k, v in pairs(def_surface_type) do
		if fxcontent.surface_type[k] == nil then
			fxcontent.surface_type[k] = v
		end
	end
end

return function (config, srcfilepath, outpath, localpath)
	local fxcontent = fs_local.datalist(srcfilepath)
	load_surface_type(fxcontent)
	local setting = config.setting
	local macros = add_macros_from_surface_setting(setting, fxcontent.surface_type, fxcontent.macros)
	local messages = {}
	local all_depends = {}
	local build_success = true
	local shader = assert(fxcontent.shader)
	for _, stagename in ipairs(valid_shader_stage) do
		local stage_file = shader[stagename]
		if stage_file then
			local shader_srcpath = localpath(stage_file)
			local success, msg, depends = toolset.compile {
				os = config.os,
				renderer = config.renderer,
				srcfile = shader_srcpath,
				outfile = outpath / stagename,
				includes = {engine_shader_srcpath},
				macros = macros,
			}
			build_success = build_success and success
			messages[#messages+1] = msg

			if success then
				for _, d in ipairs(depends) do
					if not all_depends[d] then
						all_depends[#all_depends+1] = d
						all_depends[d] = true
					end
				end
			end
		end
	end

	if build_success then
		fs_local.write_file(outpath / "main.fx", stringify(fxcontent))
	end
	table.sort(all_depends)
    table.insert(all_depends, 1, srcfilepath:string())
	return build_success, table.concat(messages, "\n"), all_depends
end
