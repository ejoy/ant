local pm = require "antpm"

return function(name)
	local ok, m = pm.try_import(name)
	if ok then
		return m
	end
	local err = m
	-- todo: recursion try
	local name, subname = name:match "(.+)%.([^.]+)$"
	if name == nil then
		error(string.format("Not found %s : %s", name, err))
	end
	local ok, m = pm.try_import(name)
	if not ok then
		error(string.format("Not found %s : %s\n\t%s", name, err,m))
	end
	if type(m) ~= "table" or m[subname] == nil then
		error(string.format("Not found .%s in %s", subname, name))
	end

	return m[subname]
end
