local fs = require "filesystem.local"
local subprocess = require "utility.sp_util"
local fs_local = require "utility.fs_local"
local platform = require "platform"

local function FBX2glTF()
	if platform.OS == "Windows" then
		return "3rd/bin/FBX2glTF-windows-x64.exe"
	end
	if platform.OS == "OSX" then
		return "3rd/bin/FBX2glTF-darwin-x64"
	end
	if platform.OS == "Linux" then
		return "3rd/bin/FBX2glTF-linux-x64"
	end
	assert(false, "unknown platform")
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
