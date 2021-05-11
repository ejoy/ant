local path_sep = package.config:sub(3,3)
if package.cpath:match(path_sep) then
	local ext = package.cpath:match '[/\\]%?%.([a-z]+)'
	package.cpath = (function ()
		local i = 0
		while arg[i] ~= nil do
			i = i - 1
		end
		local dir = arg[i + 1]:match("(.+)[/\\][%w_.-]+$")
		return ("%s/?.%s"):format(dir,ext)
	end)()
end
