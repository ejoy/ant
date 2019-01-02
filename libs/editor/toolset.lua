local subprocess = require "subprocess"
local fs = require "filesystem"
local platform = require "platform"
local OS = platform.OS

local toolset = {}

local cwd = assert(fs.current_path())

if OS == "OSX" then
	toolset.config = {
		lua = cwd .. "/bin/lua",
		shaderc = {
			cwd / "clibs/shadercDebug",
			cwd / "clibs/shadercRelease",
			cwd / "bin/shadercDebug",
			cwd / "bin/shadercRelease",
		},
		shaderinc = cwd / "3rd/bgfx/src",
	}
else
	toolset.config = {
		lua = cwd .. "/bin/lua.exe",
		shaderc = {
			cwd .. "/clibs/shadercDebug.exe",
			cwd .. "/clibs/shadercRelease.exe",
			cwd .. "/bin/shadercDebug.exe",
			cwd .. "/bin/shadercRelease.exe",
		},
		shaderinc = cwd / "3rd/bgfx/src",
	}
end

function toolset.load_config()
	return toolset.config
end

local stage_types = {
	f = "fragment",
	v = "vertex",
	c = "compute",
}

local shader_options = {
	d3d9_v = "vs_3_0",
	d3d9_f = "ps_3_0",
	d3d11_v = "vs_4_0",
	d3d11_f = "ps_4_0",
	d3d11_c = "cs_5_0",
	glsl_v ="120",
	glsl_f ="120",
	glsl_c ="430",
	metal_v = "metal",
	metal_f = "metal",
	metal_c = "metal",
	vulkan_v = "spirv",
	vulkan_f = "spirv",
}

local function searchExistPath(paths)
	if type(paths) == 'string' then
		if fs.exists(paths) then
			return paths
		end
		return
	elseif type(paths) == 'table' then
		for _, path in pairs(paths) do
			if fs.exists(path) then
				return path
			end
		end
		return
	end
end

local function default_level(shadertype, stagetype)
	if shadertype:match("d3d") then
		return stagetype == "c" and 1 or 3
	end
end

function toolset.compile(filename, paths, shadertype, platform, stagetype, shader_opt, optimizelevel)
	paths = paths or toolset.config

	if filename then
		local dest = paths.dest or filename:gsub("(%w+).sc", "%1") .. ".bin"

		local shaderc = searchExistPath(paths.shaderc)
		if not shaderc then
			error(string.format("bgfx shaderc path is privided, but file is not exist, path is : %s. \
								you can locate to ant folder, and run : bin/iup.exe tools/config.lua, to set the right path", shaderc))
		end

		local tbl = {
			shaderc = shaderc,
			src = filename,
			dest = dest,
			inc = {},
			stype = nil,
			sopt = nil,
			splat = nil,
		}

		local includes = paths.includes
		if includes then
			local function add_inc(p)
				table.insert(tbl.inc, "-i")
				table.insert(tbl.inc, p)
			end
			for _, p in ipairs(includes) do
				if not fs.exists(p) then
					error(string.format("include path : %s, but not exist!", p))
				end

				add_inc(p)
			end
			if paths.not_include_examples_common == nil then
				if paths.shaderinc and (not fs.exists(paths.shaderinc)) then
					error(string.format("bgfx shader include path is needed, \
										but path is not exist! path have been set : %s", paths.shaderinc))
				end

				local incexamplepath = paths.shaderinc / "../examples/common"
				if not fs.exists(incexamplepath) then
					error(string.format("example is needed, but not exist, path is : %s", incexamplepath))
				end

				add_inc(incexamplepath)
			end
		end

		stagetype = stagetype or filename:match "[/\\]([fvc])s_[^/\\]+.sc$"
		shader_opt = shader_opt or assert(shader_options[shadertype .. "_" .. stagetype], shadertype .. "_" .. stagetype)

		tbl.stype = assert(stage_types[stagetype], stagetype)
		tbl.splat = assert(platform)
		tbl.sopt = assert(shader_opt)

		local cmdline = {
			tbl.shaderc,
			"--platform", tbl.splat,
			"--type", tbl.stype,
			"-p", tbl.sopt,
			"-f", tbl.src,
			"-o", tbl.dest,
			tbl.inc,
			stdout = true,
			stderr = true,
			hideWindow = true,
		}

		local function add_optimizelevel(level, defaultlevel)
			level = level or defaultlevel
			if level then
				table.insert(cmdline, "-O")
				table.insert(cmdline, tostring(level))
			end
		end

		add_optimizelevel(optimizelevel, default_level(shadertype, stagetype))

		local prog = subprocess.spawn(cmdline)

		local function to_cmdline()
			local s = ""
			for _, v in ipairs(cmdline) do
				if type(v) == "table" then
					for _, vv in ipairs(v) do
						s = s .. vv .. " "
					end
				else
					s = s .. v .. " "
				end
			end

			return s
		end
		print(to_cmdline(), "shadertype", shadertype, "platform", platform)

		if not prog then
			return false, "Create shaderc process failed."
		else
			local function check_msg(info)
				local success, msg = true, ""
				if info ~= "" then
					local INFO = info:upper()
					success = INFO:find("ERROR:", 1, true) == nil
					msg = to_cmdline() .. "\n" .. info .. "\n"
				end

				return success, msg
			end

			local stds = {
				{fd=prog.stdout, info="[stdout info]:"},
				{fd=prog.stderr, info="[stderr info]:"}
			}

			local success, msg = true, ""
			while #stds > 0 do
				for idx, std in ipairs(stds) do
					local fd = std.fd
					local num = subprocess.peek(fd)
					if num == nil then
						local s, m = check_msg(std.info)
						success = success and s
						msg = msg .. "\n\n" .. m
						table.remove(stds, idx)
						break
					end

					if num ~= 0 then
						std.info = std.info .. fd:read(num)
					end
				end
			end

			return success, msg
		end
	end
end

return toolset
