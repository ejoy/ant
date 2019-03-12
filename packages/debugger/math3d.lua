local function requirefile(name)
	local path = assert(package.searchpath(name, package.path))
	local fs = require "filesystem"
	--do return assert(fs.loadfile(fs.path(path))) end
	local file = assert(fs.open(fs.path(path)))
	local ret = assert(load(file:read 'a', '=(MATH3D)'))
	file:close()
	return ret
end

return function (ms)
	return requirefile('math3d.core')(ms, "vscode-dbg")
end
