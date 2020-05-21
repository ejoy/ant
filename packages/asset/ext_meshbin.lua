local utility = require "utility"
local thread = require "thread"
local math3d = require "math3d"
local function create_bounding(bounding)
	if bounding then
		bounding.aabb = math3d.ref(math3d.aabb(bounding.aabb[1], bounding.aabb[2]))
	end
end
return {
    loader = function (filename)
        local c = utility.read_file(filename)
        local meshscene = thread.unpack(c)
        for _, scene in pairs(meshscene.scenes) do
            for _, meshnode in pairs(scene) do
                local skin = meshnode.skin
                create_bounding(meshnode.bounding)
                for _, prim in ipairs(meshnode) do
                    create_bounding(prim.bounding)
                    prim.skin = skin
                end
            end
        end
    end,
    unloader = function ()
    end,
}
