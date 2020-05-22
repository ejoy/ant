local function getcpath()
	if os.getenv "HOME" then
		return "clibs/?.dll"
	end

	local i = 0
	while arg[i] ~= nil do
		i = i - 1
	end
	
	local clibs = arg[i + 1]:match("(.+)[/\\][%w_.-]+$")
	local ext = "dll"

	return ("%s/?.%s"):format(clibs, ext)
end
package.cpath = getcpath()
