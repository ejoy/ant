return function (filepath)
	local env = {}
	local r = assert(loadfile(filepath:string(), "t", env))
	r()
	return env
end
