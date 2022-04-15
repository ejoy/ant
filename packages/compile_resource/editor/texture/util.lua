local samplerutil = import_package "ant.render".sampler
local stringify = import_package "ant.serialize".stringify

local lfs = require "filesystem.local"
local subprocess = import_package "ant.subprocess"
local bgfx = require "bgfx"
local image = require "image"

local TEXTUREC = subprocess.tool_exe_path "texturec"

local function add_option(commands, name, value)
	if name then
		commands[#commands+1] = name
	end
	
	if value then
		commands[#commands+1] = value
	end
end

local function gen_commands(commands, param, input, output)
	add_option(commands, "-f", input:string())
	add_option(commands, "-o", output:string())
	if param.format then
		add_option(commands, "-t", param.format)
	end
	add_option(commands, "-q", "fastest")

	add_option(commands, "--max", tostring(param.maxsize and param.maxsize or 512))

	if param.normalmap then
		add_option(commands, "-n")
	end

	param.colorspace = param.colorspace or "sRGB"
	if param.colorspace == "linear" then
		add_option(commands, "--linear")
	elseif param.colorspace == "HDR" then
		print("not support HDR format right now")
	end

	--if param.mipmap ~= nil then
		add_option(commands, "-m")
	--end

	if param.skip_mip then
		add_option(commands, "--mipskip", tostring(param.skip_mip))
	end
end

local function writefile(filename, data)
	local f = assert(lfs.open(filename, "wb"))
	f:write(data)
	f:close()
end

local function default_sampler()
	return {
		U="WRAP",
		V="WRAP",
		W="WRAP",
		MIN="LINEAR",
		MAG="LINEAR",
		MIP="POINT",
	}
end

local function fill_default_sampler(sampler)
	local d = default_sampler()
	if sampler == nil then
		return d
	end

	for k, v in pairs(d) do
		if sampler[k] == nil then
			sampler[k] = v
		end
	end

	return sampler
end

local function readall(filename)
	local f = assert(lfs.open(filename, "rb"))
	local data = f:read "a"
	f:close()
	return data
end

return function (output, param)
	local config = {
        sampler = fill_default_sampler(param.sampler),
        flag	= samplerutil.sampler_flag(param.sampler),
    }
    if param.colorspace == "sRGB" then
        config.flag = config.flag .. 'Sg'
    end
	local imgpath = param.local_texpath
	if imgpath then
		local binfile = output / ("main."..param.setting.ext)
		local commands = {
			TEXTUREC
		}
		gen_commands(commands, param, imgpath, binfile)
		do
			local ss = {}
			for _, c in ipairs(commands) do
				ss[#ss+1] = tostring(c)
			end
			print("convert texture command:", table.concat(ss, " "))
		end
		local success, msg = subprocess.spawn_process(commands)
		if success then
			if msg:upper():find("ERROR:", 1, true) then
				success = false
			end
		end
		if not success then
			return false, msg
		end
		assert(lfs.exists(binfile))
		lfs.rename(binfile, output / "main.bin")
		
		local m = bgfx.memory_buffer(readall(output / "main.bin"))
		local info = image.parse(m)
		config.info = info
	else
		local s = param.size
		local fmt = param.format
		local ti = {}
		local w, h = s[1], s[2]
		ti.width, ti.height = w, h
		ti.format = fmt
		ti.mipmap = false
		ti.depth = 1
		ti.numLayers = 1
		ti.cubemap = false
		ti.storageSize = w*h*4
		ti.numMips = 1
		ti.bitsPerPixel = 32
		config.info = ti
		config.value = param.value
	end
    writefile(output / "main.cfg", stringify(config))
    return true
end
