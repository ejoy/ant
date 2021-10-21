local thread = require "bee.thread"

local function bootstrap(name, code)
	if code == nil then
		code = name
		name = "<thread>"
	end
	return ([=[
--%s
package.path = %q
package.cpath = %q
return assert(load(%q))()]=]):format(name, package.path, package.cpath, code)
end

local function createThread(name, code)
	return thread.thread(bootstrap(name, code))
end

return {
	create = createThread,
	bootstrap = bootstrap,
	wait = thread.wait,
}
