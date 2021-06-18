local samplerutil = import_package "ant.render".sampler
local stringify = import_package "ant.serialize".stringify

local lfs = require "filesystem.local"
local subprocess = require "sp_util"
local identity_util = require "identity"

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
	add_option(commands, "-t", param.format)
	add_option(commands, "-q", "fastest")

	if param.maxsize then
		add_option(commands, "--max", param.maxsize)
	end

	if param.normalmap then
		add_option(commands, "-n")
	end

	param.colorspace = param.colorspace or "sRGB"
	if param.colorspace == "linear" then
		add_option(commands, "--linear")
	elseif param.colorspace == "HDR" then
		print("not support HDR format right now")
	end

	local mipmap = param.mipmap
	if mipmap then
		add_option(commands, "-m")
		if mipmap ~= 0 then
			add_option(commands, "--mipskip", tostring(mipmap))
		end
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

local extensions = {
	direct3d11 	= "dds",
	direct3d12 	= "dds",
	metal 		= "ktx",
	vulkan 		= "ktx",
	opengl 		= "ktx",
}

return {
    convert_image = function (output, param)
		local config = {
			name = param.name,
            sampler = fill_default_sampler(param.sampler),
            flag	= samplerutil.sampler_flag(param.sampler),
        }

		local imgpath = param.local_texpath
		if imgpath then
			local binfile = param.binfile
			local commands = {
				TEXTUREC
			}
			gen_commands(commands, param, imgpath, binfile)

			local success, msg = subprocess.spawn_process(commands)
			if success then
				if msg:upper():find("ERROR:", 1, true) then
					success = false
				end
			end
			if not success then
				return false, msg
			end

			config.name	= param.name or imgpath:string()
			assert(lfs.exists(binfile))
			lfs.rename(binfile, output / "main.bin")
		else
			config.size = param.size
			config.format = param.format
		end

        if param.colorspace == "sRGB" then
            config.flag = config.flag .. 'Sg'
        end
        writefile(output / "main.cfg", stringify(config))
        return true
    end,
    what_bin_file = function (output, identity)
		local id = type(identity) == "string" and identity_util.parse(identity) or identity
        local ext = assert(extensions[id.renderer])
        return (output / "main.bin"):replace_extension(ext)
    end,
}