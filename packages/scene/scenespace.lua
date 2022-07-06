local ecs = ...
local world = ecs.world
local w = world.w

local s = ecs.system "scenespace_system"

local function inherit_state(r, pr)
	if r.fx == nil then
		r.fx = pr.fx
	end
	if r.material == nil then
		r.material = pr.material
	end
end

local function update_render_object(ro, scene)
	if ro then
		ro.worldmat = scene.worldmat
		if scene.parent ~= 0 then
			local parent = world:entity(scene.parent)
			if parent then
				local pr = parent.render_object
				if pr then
					inherit_state(ro, pr)
				end
			else
				error "Unexpected Error."
			end
		end
	end
end

function s:entity_init()
	for v in w:select "INIT scene:in render_object?in scene_needchange?out" do
		local scene = v.scene
		v.scene_needchange = true
		update_render_object(v.render_object, scene)
	end
end

function s:scene_update()
	for e in w:select "scene_changed scene:in render_object:in" do
		e.render_object.worldmat = e.scene.worldmat
        e.render_object.aabb = e.scene.scene_aabb
	end
end

function ecs.method.set_parent(e, parent)
	world:pub {"parent_changed", e, parent}
end

local sceneupdate_sys = ecs.system "scene_update_system"
function sceneupdate_sys:init()
	ecs.group(0):enable "scene_update"
	ecs.group_flush()
end

local g_sys = ecs.system "group_system"
function g_sys:start_frame()
	ecs.group_flush()
end
