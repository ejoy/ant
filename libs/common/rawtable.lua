local function default_readcontent(filepath)
	local f = io.open(filepath:string(),"rb")
	local data = f:read "a"
	f:close()
	return data
end

return function (filepath, readcontent)
	readcontent = readcontent or default_readcontent
	local data = readcontent(filepath)
	local env = {}
	local r = assert(load (data, "@" .. filepath:string(), "bt", env))
	r()
	return env
end
