local function requirefile(name)
	local path = assert(package.searchpath(name, package.path))
	--do return assert(loadfile(path)) end
	local file = assert(io.open(path))
	local ret = assert(load(file:read 'a', '=(MATH3D)'))
	file:close()
	return ret
end

return function (ms)
	return requirefile('debugger.math3d.core')(ms, "vscode-dbg")
end
