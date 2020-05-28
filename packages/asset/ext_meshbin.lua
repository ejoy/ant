local cr = import_package "ant.compile_resource"
local thread = require "thread"
local math3d = require "math3d"
local function create_bounding(bounding)
	if bounding then
		bounding.aabb = math3d.ref(math3d.aabb(bounding.aabb[1], bounding.aabb[2]))
	end
end
return {
    loader = function (filename)
        local c = cr.read_file(filename)
        local group = thread.unpack(c)
        create_bounding(group.bounding)
        return group
    end,
    unloader = function ()
    end,
}
