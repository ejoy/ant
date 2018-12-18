local ecs = ...
local world = ecs.world

ecs.import "render.constant_system"
ecs.import "inputmgr.message_system"

-- light entity
ecs.import "serialize.serialize_component"
ecs.import "render.light.light"
ecs.import "scene.filter.lighting_filter"

-- enable
ecs.import "serialize.serialize_system"
ecs.import "render.view_system"
ecs.import "render.entity_rendering_system"
ecs.import "scene.hierarchy.hierarchy"
--ecs.import "scene.cull_system"

ecs.import "editor.ecs.editor_component"

local component_util = require "render.components.util"
local ms = require "math.stack"
local model_review_system = ecs.system "model_review_system"

model_review_system.singleton "constant"
model_review_system.depend "constant_init_sys"
model_review_system.dependby "message_system"

local bgfx = require "bgfx"
local lu = require "render.light.util"
local cu = require "render.components.util"
local mu = require "math.util"

local function create_light()
	local leid = lu.create_directional_light_entity(world)
	local lentity = world[leid]
	local lightcomp = lentity.light
	lightcomp.color = {1,1,1,1}
	lightcomp.intensity = 2.0
	ms(lentity.rotation, {123.4, -34.22,-28.2}, "=")

	local am_eid = lu.create_ambient_light_entity(world)
	local am_entity = world[am_eid]
	local ambient_comp = am_entity.ambient_light
	ambient_comp.mode = "color" 
	ambient_comp.skycolor = {1,1,1,1}
	ambient_comp.midcolor  = {0.9,0.9,1,1}
	ambient_comp.groundcolor  = {0.60,0.74,0.68,1}
end

local function create_grid()
	local gridid = world:new_entity(
		"rotation", "position", "scale", 
		"can_render", "mesh", "material",
		"name"
	)
    local grid = world[gridid]
    grid.name = "grid"
    mu.identify_transform(grid)

    local function create_grid_line_points(w, h, unit)
        local t = {"fffd"}
        local function add_point(x, z, clr)
            table.insert(t, x)
            table.insert(t, 0)
            table.insert(t, z)
            table.insert(t, clr)
        end

        local w_len = w * unit
        local hw_len = w_len * 0.5

        local h_len = h * unit
        local hh_len = h_len * 0.5

        local color = 0x88c0c0c0

        -- center lines
        add_point(-hh_len, 0, 0x8800ff)
        add_point(hh_len, 0, 0x880000ff)

        add_point(0, -hw_len, 0x88ff0000)
        add_point(0, hw_len, 0x88ff0000)

        -- column lines
        for i=0, w do
            local x = -hw_len + i * unit
            add_point(x, -hh_len, color)
            add_point(x, hh_len, color)
        end

        -- row lines
        for i=0, h do
            local y = -hh_len + i * unit
            add_point(-hw_len, y, color)
            add_point(hw_len, y, color)
        end
        return t
    end

    local vdecl = bgfx.vertex_decl {
        { "POSITION", 3, "FLOAT" },
        { "COLOR0", 4, "UINT8", true }
    }

	grid.mesh.path = ""
    grid.mesh.assetinfo = {
		handle = {
			groups = {
				{
					vb = {
						decls = {
							vdecl
						},
						handles = {
							bgfx.create_vertex_buffer(
								create_grid_line_points(64, 64, 1),
								vdecl)
						}
					}
				}
			}
		}
	}

	grid.material.content[1] = {path="line.material", properties={}}
	cu.load_material(grid.material)
end

function model_review_system:init()
	create_light()
	create_grid()

	local eid = world:new_entity(
		"position", "rotation", "scale",
		"can_render", "mesh", "material"
	)
	local model = world[eid]
	component_util.load_mesh(model.mesh,"PVPScene/campsite-door.mesh")
	component_util.load_material(model.material,{"PVPScene/scene-mat.material"})
	--component_util.load_mesh(model.mesh,"cube.mesh")
	--component_util.load_material(model.material,{"bunny.material"})

	local mesh = model.mesh.assetinfo.handle.bounding
	--local bound = ms(mesh.aabb.max, mesh.aabb.min, "-T")
	--local scale = 10 / math.max(bound[1], math.max(bound[2], bound[3]))
	--ms(model.scale, {scale, scale, scale, 0}, "=")
	--ms(model.position, {0, 0, 0, 1}, {0,mesh.aabb.min[2],0,1}, {scale}, "*-=")
	ms(model.scale, {0.2, 0.2, 0.2, 0}, "=")
	ms(model.position, {0, 0, 0, 1}, "=")
	ms(model.rotation, {-90, -90, 0,}, "=")
end
