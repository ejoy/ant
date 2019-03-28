--luacheck: ignore self
local ecs = ...
local world = ecs.world

local geometry_drawer = import_package "ant.geometry".drawer

ecs.component_alias("can_show_bounding", "boolean") {depend="can_render"}

local rmb = ecs.system "render_mesh_bounding"
rmb.singleton "debug_object"
rmb.dependby "debug_draw"

function rmb:update()
	local dbgobj = self.debug_object
	local renderobj = dbgobj.renderobjs.wireframe
	local desc = renderobj.desc
	for _, eid in world:each "can_show_bounding" do
		local e = world[eid]
		if e.can_show_bounding then
			local m = e.mesh
			for _, g in ipairs(m.assetinfo.handle.groups) do
				local b = g.bounding
				if b then
					geometry_drawer.draw_aabb_box(b.aabb, 0xffffff00, nil, desc)
				end
			end
		end
	end
end