local ecs = ...
local world = ecs.world
local math3d = require "math3d"

local sp = ecs.system "scenespace"

local se_mb = world:sub {"component_register", "scene_entity"}
local eremove_mb = world:sub {"entity_removed"}

local hie_scene = require "hierarchy.scene"
local scenequeue = hie_scene.queue()

function sp:update_hierarchy_scene()
	for _, _, eid in se_mb:unpack() do
        scenequeue:mount(eid, world[eid].parent or 0)
    end

    local needclear
    for _, eid in eremove_mb:unpack() do
        scenequeue:mount(eid)
        needclear = true
    end

    if needclear then
        scenequeue:clear()
    end
end

function sp:update_transform()
	for _, eid in ipairs(scenequeue) do
		local e = world[eid]

		-- hierarchy scene can do everything relative to hierarchy, such as:
		-- hierarhcy visible/material/transform, and another reasonable data

		local trans = e.transform
		-- calculate local info
		if trans then
			trans.world.m = trans.srt
		end

		--combine parent info
		local peid = e.parent
		if peid then
			local pe = world[peid]
			local ptrans = pe.transform
			
			if ptrans then
				local pw = ptrans.world
				trans.world.m = math3d.mul(pw, trans.world)
			end
		end
	end
end