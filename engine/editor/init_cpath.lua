local function getcpath()
	local i = 0
	while arg[i] ~= nil do
		i = i - 1
	end
	local dir = arg[i + 1]:match("(.+)[/\\][%w_.-]+$")
	return ("%s/?.dll"):format(dir)
end
package.cpath = getcpath()
