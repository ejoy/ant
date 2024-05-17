local subprocess 	= require "subprocess"
local sampler 		= import_package "ant.render.core".sampler
local lfs 			= require "bee.filesystem"
local image 		= require "image"
local math3d		= require "math3d"
local fastio		= require "fastio"

local stringify 	= import_package "ant.serialize".stringify

local TEXTUREC 		= require "tool_exe_path"("texturec")
local shpkg			= import_package "ant.sh"
local SH			= shpkg.sh
local texcube		= import_package "ant.texture".cube
local btime			= require "bee.time"

local setting		= import_package "ant.settings"

local irradianceSH_bandnum<const> = setting:get "graphic/ibl/irradiance_bandnum"

local function add_option(commands, name, value)
	if name then
		commands[#commands+1] = name
	end
	
	if value then
		commands[#commands+1] = value
	end
end

local function which_format(setting, param)
	local compress = param.compress
	if compress then
		local os = setting.os
		if os == "ios" or os == "macos" then
			return "ASTC4x4"
		end
		return compress[os]
	end

	return param.format
end

local function gen_commands(commands, setting, param, input, output)
	add_option(commands, "-f", input)
	add_option(commands, "-o", output)
	local fmt = which_format(setting, param)
	if fmt then
		add_option(commands, "-t", fmt)
	end
	add_option(commands, "-q", "fastest")

	if param.noresize == nil then
		add_option(commands, "--max", tostring(param.maxsize or 256))
	end

	if param.normalmap then
		add_option(commands, "-n")
	end
 	if param.equirect then
		add_option(commands, "--equirect")
	end 
	param.colorspace = param.colorspace or "sRGB"
	if param.colorspace == "linear" then
		add_option(commands, "--linear")
	elseif param.colorspace == "HDR" then
		print("not support HDR format right now")
	end

	if param.mipmap ~= nil then
		add_option(commands, "-m")
		if param.skip_mip then
			add_option(commands, "--mipskip", tostring(param.skip_mip))
		end
	end

end

local function writefile(filename, data)
	local f <close> = assert(io.open(filename:string(), "wb"))
	f:write(data)
end

local function is_png(path)
	return path:extension() == ".png"
end

local function gray2rgb(path, outfile)
	local c = fastio.readall_f(path:string())
	local fc = image.png.gray2rgba(c)
	if fc then
		writefile(outfile, fc)
		return outfile
	end
	return path
end

local compress_SH; do
    local P<const> = {
        [2] = function (Eml)
            local m = math3d.transpose(math3d.matrix(Eml[1], Eml[2], Eml[3], Eml[4]))
            local c1, c2, c3 = math3d.index(m, 1, 2, 3)
            return {c1, c2, c3}
        end,
        [3] = function (Eml)
            local m1 = math3d.transpose(math3d.matrix(Eml[2], Eml[3], Eml[4], Eml[5]))
            local m2 = math3d.transpose(math3d.matrix(Eml[6], Eml[7], Eml[8], Eml[9]))
            local c1, c2, c3 = math3d.index(m1, 1, 2, 3)
            local c4, c5, c6 = math3d.index(m2, 1, 2, 3)
            return {Eml[1], c1, c2, c3, c4, c5, c6}
        end
    }

    compress_SH = P[irradianceSH_bandnum]
end

local function build_Eml(cm)
    print("start build irradiance SH, bandnum:", irradianceSH_bandnum)
	local now = btime.monotonic()
    local Eml = SH.calc_Eml(cm, irradianceSH_bandnum)
    print("finish build irradiance SH, time used: ", btime.monotonic() - now, " ms")
    return Eml
end

local function serialize_results(Eml)
    local s = {}
    for _, e in ipairs(Eml) do
        s[#s+1] = math3d.tovalue(e)
    end
	return s
end

local function build_irradiance_sh(cm)
    local Eml = compress_SH(build_Eml(cm))
	return serialize_results(Eml)
end

local TextureExtensions <const> = {
	direct3d11 = "dds",
	direct3d12 = "dds",
	metal      = "ktx",
	vulkan     = "ktx",
	opengl     = "ktx",
}

local function getExtensions(setting)
	if setting.renderer == "noop" then
		return setting.os == "windows" and "dds" or "ktx"
	end
	return assert(TextureExtensions[setting.renderer])
end

return function (output, setting, param)
    lfs.remove_all(output)
    lfs.create_directories(output)
	local config = {
        flag	= sampler(param.sampler),
    }
    if param.colorspace == "sRGB" then
        config.flag = config.flag .. 'Sg'
    end
	if param.dynamic then
		config.flag = config.flag .. "rt"
		config.dynamic = true
	end
	local imgpath = param.path

	config.build_irradianceSH = param.build_irradianceSH

	local buildcmd
	if imgpath then
		local ext = getExtensions(setting)
		local binfile = output / ("main."..ext)
		if is_png(imgpath) and param.gray2rgb then
			local tmpfile = output / ("tmp." .. ext)
			imgpath = gray2rgb(imgpath, tmpfile)
		end
		local commands = {
			TEXTUREC
		}
		gen_commands(commands, setting, param, imgpath:string(), binfile:string())
		print("texture compile:")
		local function to_command(commands)
			local t = {}
			for _, cmd in ipairs(commands) do
				t[#t+1] = tostring(cmd)	-- make lfs.path to string
			end
			return table.concat(t, " ")
		end
		buildcmd = to_command(commands)
		local success, errmsg, outmsg = subprocess.spawn(commands)
		if success then
			if outmsg:upper():find("ERROR:", 1, true) then
				success = false
			end
		end
		if not success then
			return false, errmsg
		end
		assert(lfs.exists(binfile))
		local output_bin = output / "main.bin"
		lfs.rename(binfile, output_bin)

		local info = image.parse(fastio.readall_f(output_bin:string()))
		config.info = info
		config.image = imgpath:string()
		if param.lattice then
			config.info.lattice = param.lattice
		end
		if param.atlas then
			config.info.atlas = param.atlas
		end
		if config.build_irradianceSH then
			local nomip<const> = true
			local info, content = image.parse(fastio.readall_f(output_bin:string()), true, "RGBA32F", nomip)
			if not info.cubeMap then
				error "build SH need cubemap texture"
			end
			assert(info.bitsPerPixel // 8 == 16)
			local cm = texcube.create{w=info.width, h=info.height, texelsize=16, data=content}
			config.irradiance_SH = build_irradiance_sh(cm)
		end
	else
		buildcmd = "<image from memory>"
		local s = param.size
		local fmt = param.format
		local ti = {}
		local w, h = s[1], s[2]
		ti.width, ti.height = w, h
		ti.format = fmt
		ti.mipmap = false
		ti.depth = 1
		ti.numLayers = param.numLayers or 1
		ti.cubeMap = param.cubemap or false
		ti.storageSize = w*h*4
		if param.dynamic then
			ti.numMips = 0
		else
			ti.numMips = 1
		end
		ti.bitsPerPixel = 32
		config.info = ti
		config.value = param.value
	end

	local content = ("#%s\n%s"):format(buildcmd, stringify(config))
    writefile(output / "source.ant", content)
    return true
end
