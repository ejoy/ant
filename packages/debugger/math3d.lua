local fs = require "filesystem"

local function loadfile(path)
	local f = assert(fs.open(fs.path(path)))
	local str = f:read 'a'
	f:close()
	return str
end

local function requirefile(name)
	local path = assert(package.searchpath(name, package.path))
	--do return assert(fs.loadfile(fs.path(path))) end
	return assert(load(loadfile(path), '=(MATH3D)'))
end

return function (ms)
	return requirefile('math3d.core')(ms, "vscode-dbg")
end
