local fs = require "filesystem.local"
local subprocess = require "utility.sp_util"
local fs_local = require "utility.fs_local"

return function (input, output)
	local toolexe = fs_local.valid_tool_exe_path "FBX2glTF-windows-x64"
	output = output or input
	output = fs.path(output):replace_extension("")	-- should not pass filename with extension, just filename without any extension
	local commands = {
		toolexe:string(),
		"-i", input:string(),
		"-o", output:string(),
		"-b",
		"--compute-normals", "missing",
		"--pbr-metallic-roughness",
		stdout = true,
		stderr = true,
		hideWindow = true,
	}
	local notwait <const> = true
	local process = subprocess.spawn_process(commands, nil, notwait)
	local success, msg = process.wait()
	print("convert file:", input:string(), success and "success" or "failed")
	print(msg)
	return success
end
