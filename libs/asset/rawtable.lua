return function (filename)
	local f = io.open(filename,"rb")
	local data = f:read "a"
	f:close()
	local env = {}
	local r = assert(load (data, "@" .. filename, "bt", env))
	r()
	return env
end
