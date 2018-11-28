local function default_readcontent(filename)
	local f = io.open(filename,"rb")
	local data = f:read "a"
	f:close()
	return data
end

return function (filename, readcontent)
	readcontent = readcontent or default_readcontent
	local data = readcontent(filename)
	local env = {}
	local r = assert(load (data, "@" .. filename, "bt", env))
	r()
	return env
end
