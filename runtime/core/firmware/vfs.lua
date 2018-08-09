local vfs = {}

local _F	-- firmware dir
local _D	-- vfs dir

function vfs.init(firmware, dir)
	local stripe_sep = "(.-)[/\\]*$"
	_F = firmware:gsub(stripe_sep,"%1/")
	_D = dir:gsub(stripe_sep,"%1/")
end

function vfs.open(path)
	local f = io.open(_D .. path, "r")
	if f then
		return f
	end
	local subpath = path:match("^%.firmware[/\\](.+)")
	if subpath then
		return io.open(_F .. subpath, "r")
	end
end

return vfs
