local path_sep = package.config:sub(1,1) == "\\" and ";" or ":"
if package.cpath:match(path_sep) then
	package.cpath = (function ()
		local i = 0
		while arg[i] ~= nil do
			i = i - 1
		end
		local dir = arg[i + 1]:match("(.+)[/\\][%w_.-]+$")
		return ("%s/?.dll"):format(dir)
	end)()
end
