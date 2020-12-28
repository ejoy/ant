local fs = require "filesystem.local"
local subprocess = require "sp_util"
local platform = require "platform"

local bin_files = {
	Windows = "bin/msvc/FBX2glTF-windows-x64.exe",
	OSX = "bin/osx/FBX2glTF-darwin-x64",
	Linux = "bin/linux/FBX2glTF-linux-x64",
}

local function FBX2glTF()
	return assert(bin_files[platform.OS], "unknown platform")
end

return function (input, output)
	output = output or input
	output = fs.path(output):replace_extension("")	-- should not pass filename with extension, just filename without any extension
	local commands = {
		FBX2glTF(),
		"-i", input:string(),
		"-o", output:string(),
		"-b",
		"--compute-normals", "missing",
		"--pbr-metallic-roughness",
	}
	local success, msg = subprocess.spawn_process(commands)
	print(msg)
	return success
end
