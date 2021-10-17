local ltask = require "ltask"
local ServiceResource = ltask.uniqueservice "ant.compile_resource|resource"
local cr        = import_package "ant.compile_resource"

local function loader(filename)
	local result = ltask.call(ServiceResource, "texture_create", filename, cr.compile_path(filename))
	if result.uncomplete then
		ltask.fork(function()
			result.handle = ltask.call(ServiceResource, "texture_complete", filename)
			result.uncomplete = nil
		end)
	end
	return result
end

local function unloader(res)
	--TODO
	ltask.call(ServiceResource, "texture_destroy", res)
end

return {
    loader = loader,
    unloader = unloader,
}
