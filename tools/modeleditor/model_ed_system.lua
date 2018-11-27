local ecs = ...
local world = ecs.world

-- runtime
ecs.import "render.camera.camera_component"
ecs.import "render.entity_rendering_system"
ecs.import "render.view_system"


-- lighting
ecs.import "render.light.light"

-- serialize
ecs.import "serialize.serialize_system"

-- scene
ecs.import "scene.cull_system"
ecs.import "scene.filter.filter_system"
ecs.import "scene.filter.lighting_filter"

-- animation
ecs.import "animation.skinning.skinning_system"
ecs.import "animation.animation"
ecs.import "physic.rigid_body"

-- editor
ecs.import "editor.ecs.camera_controller"
ecs.import "editor.ecs.pickup_system"
ecs.import "editor.ecs.render.widget_system"

-- editor elements
ecs.import "editor.ecs.general_editor_entities"
local bu = require "bullet.lua.util"

local bgfx = require "bgfx"

local ms = require "math.stack"

local model_ed_sys = ecs.system "model_editor_system"

model_ed_sys.depend "camera_init"

-- luacheck: globals model_windows
-- luacheck: globals iup
local windows = model_windows()

local assetmgr = require "asset"
local comp_util = require "render.components.util"
local fu = require "filesystem.util"

local modelutil = require "modelloader.util"
local me_util = require "tools.modeleditor.util"


local function gen_mesh_assetinfo(skinning_mesh_comp)	
	local skinning_mesh = skinning_mesh_comp.assetinfo.handle

	local decls = {}
	local vb_handles = {}
	local vb_data = {"!", "", 1}
	for _, type in ipairs {"dynamic", "static"} do
		local layout = skinning_mesh:layout(type)
		local decl = modelutil.create_decl(layout)
		table.insert(decls, decl)

		local buffer, size = skinning_mesh:buffer(type)
		vb_data[2], vb_data[3] = buffer, size
		if type == "dynamic" then
			table.insert(vb_handles, bgfx.create_dynamic_vertex_buffer(vb_data, decl))
		elseif type == "static" then
			table.insert(vb_handles, bgfx.create_vertex_buffer(vb_data, decl))
		end
	end

	local function create_idx_buffer()
		local idx_buffer, ib_size = skinning_mesh:index_buffer()	
		if idx_buffer then			
			return bgfx.create_index_buffer({idx_buffer, ib_size})
		end

		return nil
	end

	local ib_handle = create_idx_buffer()

	return {
		handle = {
			groups = {
				{
					bounding = skinning_mesh:bounding(),
					vb = {
						decls = decls,
						handles = vb_handles,
					},
					ib = {
						handle = ib_handle,
					}
				}
			}
		},			
	}
end

local smaplemaerial = "skin_model_sample.material"

local sample_obj_user_idx = 1
local plane_obj_user_idx = 2

local function add_aabb_widget(eid)
	world:add_component(eid, "widget")
	local e = world[eid]
	local aabb_material = "line.material"
	local descs = me_util.create_aabb_descs(e.mesh, aabb_material)
	if #descs == 0 then
		return 
	end

	local ibhandle = bgfx.create_index_buffer(descs[1].ib)
	local decl = bgfx.vertex_decl {
		{ "POSITION", 3, "FLOAT" },
		{ "COLOR0", 4, "UINT8", true },
	}

	local function create_mesh_groups(descs, color)
		local groups = {}
		for _, desc in ipairs(descs) do
			local vb = {"fffd",}
			for _, v in ipairs(desc.vb) do
				for _, vv in ipairs(v) do
					table.insert(vb, vv)
				end
				table.insert(vb, color)
			end

			table.insert(groups, {
					vb = {handles = {	bgfx.create_vertex_buffer(vb, decl)	}},
					ib = {handle = ibhandle},
				})
		end

		return groups
	end

	local widget = e.widget
	widget.mesh = {
		descs = descs,
		assetinfo = {
			handle = {
				groups = create_mesh_groups(descs, 0xffff0000),
			}
		}
	}

	widget.material = {
		content = {}
	}
	comp_util.load_material(widget.material, {aabb_material})

	widget.srt = {}--{s=e.scale, r=nil, t=e.position}
end

local function create_sample_entity(skepath, anipath, skinning_meshpath)
	local eid = world:new_entity("position", "scale", "rotation",	
	"rigid_body",		-- physic relate
	"mesh", "material",
	"name", "can_render")

	local e = world[eid]
	e.name = "animation_test"

	local mu = require "math.util"
	mu.identify_transform(e)

	if skepath and skepath ~= "" then
		world:add_component(eid, "skeleton")
		comp_util.load_skeleton(e.skeleton, skepath)
	end

	if anipath and anipath ~= "" then
		world:add_component(eid, "animation")
		comp_util.load_animation(e.animation, e.skeleton, anipath)
	end

	local skinning_mesh
	if skinning_meshpath and skinning_meshpath ~= "" then
		if e.skeleton and e.animation then
			world:add_component(eid, "skinning_mesh")
			skinning_mesh = e.skinning_mesh
		else
			skinning_mesh = {}
		end

		comp_util.load_skinning_mesh(skinning_mesh, skinning_meshpath)			
	end
	
	e.mesh.assetinfo = gen_mesh_assetinfo(skinning_mesh)

	local function init_physic_obj()
		local rigid_body = e.rigid_body
		
		local aabb = e.mesh.assetinfo.handle.groups[1].bounding.aabb
		local len = math.sqrt(ms(aabb.max, aabb.min, "-1.T")[1])

		local phy_world = world.args.physic_world

		local shape = {type= "capsule", radius=0.1 * len, height=0.8 * len, axis=2}
		shape.handle = bu.create_shape(phy_world, shape.type, shape)		
		table.insert(rigid_body.shapes, shape)
		
		local colobj = assert(rigid_body).obj
		colobj.handle = phy_world:new_obj(shape.handle, sample_obj_user_idx, {0, 0, 0}, {0, 0, 0, 1})
		colobj.useridx = sample_obj_user_idx
	end

	init_physic_obj()

	comp_util.load_material(e.material,{smaplemaerial})

	add_aabb_widget(eid)
	return eid
end

local function get_ani_cursor(slider)
	assert(tonumber(slider.MIN) == 0)
	assert(tonumber(slider.MAX) == 1)
	return tonumber(slider.VALUE)
end

local function update_animation_ratio(eid, cursor_pos)
	local e = world[eid]	
	local anicomp = e.animation
	if anicomp then
		anicomp.ratio = cursor_pos
	end
end

local function create_plane_entity()
	local eid = world:new_entity("position", "rotation", "scale",
		"mesh", "material",
		"rigid_body",
		"name", "can_render")

	local plane = world[eid]
	local function create_plane_mesh_info()
		local decl = bgfx.vertex_decl {
			{ "POSITION", 3, "FLOAT" },
            { "NORMAL", 3, "FLOAT" },
            { "COLOR0", 4, "UINT8", true },
		}
		local unit = 5
		local half_unit = unit * 0.5
		return {
			handle = {
				groups = {
					{
						bounding = {
							aabb = {
								min = {},
								max = {},
							},
							sphere = {
								center = {},
								radius = 1,
							}
						},
						vb = {
							decls = {decl},
							handles = {
								bgfx.create_vertex_buffer(
									{
										"ffffffd",
										-half_unit, 0, half_unit,
										0, 1, 0,
										0xff080808,

										half_unit, 0, half_unit,
										0, 0, 0,
										0xff080808,

										half_unit, 0, -half_unit,
										0, 0, 0,
										0xff080808,
									},
									decl)
							}
						},					
					}
				}
			}
		}
	end

	plane.mesh.assetinfo = create_plane_mesh_info()

	comp_util.load_material(plane.material,{smaplemaerial})

	-- rigid_body
	local rigid_body = plane.rigid_body
	local shape = {type="plane", nx=0, ny=1, nz=0, distance=10}

	local physic_world = world.args.physic_world
	shape.handle = bu.create_shape(physic_world, shape.type, shape)
	table.insert(rigid_body.shapes, shape)

	rigid_body.obj.handle = physic_world:new_obj(shape.handle, plane_obj_user_idx, {0, 0, 0}, {0, 0, 0, 1})
	rigid_body.obj.useridx = plane_obj_user_idx
end

local sample_eid

local function init_control()
	local skepath_ctrl = windows.ske_path
	local anipath_ctrl = windows.ani_path
	local meshpath_ctrl = windows.mesh_path

	local function check_create_sample_entity(sc, ac, mc)
		local anipath = ac.VALUE
		local skepath = sc.VALUE
		local skinning_meshpath = mc.VALUE

		local function check_path_valid(pp)
			if pp == nil or pp == "" then
				return false
			end

			if not assetmgr.find_valid_asset_path(pp) then
				iup.Message("Error", string.format("invalid path : %s", pp))
				return false
			end

			return true
		end

		-- only skinning meshpath is needed!
		if check_path_valid(skinning_meshpath) then			
			if sample_eid then
				world:remove_entity(sample_eid)
			end

			sample_eid = create_sample_entity(skepath, anipath, skinning_meshpath)
		end
	end

	function skepath_ctrl:killfocus_cb()		
		check_create_sample_entity(self, anipath_ctrl, meshpath_ctrl)
		return 0
	end
	
	function anipath_ctrl:killfocus_cb()
		check_create_sample_entity(skepath_ctrl, self, meshpath_ctrl)
		return 0
	end

	function meshpath_ctrl:killfocus_cb()
		check_create_sample_entity(skepath_ctrl, anipath_ctrl, self)
	end

	-- skepath_ctrl.VALUE=fu.write_to_file("cache/ske.ske", [[path="meshes/skeleton/skeleton"]])
	-- anipath_ctrl.VALUE=fu.write_to_file("cache/ani.ani", [[path="meshes/animation/animation_base"]])
	meshpath_ctrl.VALUE = "meshes/mesh.ozz"
	check_create_sample_entity(skepath_ctrl, anipath_ctrl, meshpath_ctrl)

	local slider = windows.anitime_slider
	local dlg = iup.GetDialog(slider)

	local function update_static_duration_value()
		if sample_eid then
			local e = world[sample_eid]
			local ani = e.animation
			if ani then 
				local anihandle = ani.assetinfo.handle
				
				local duration = anihandle:duration()			
				local static_duration_value = iup.GetDialogChild(dlg, "STATIC_DURATION")
				static_duration_value.TITLE = string.format("Time(%.2f ms)", duration * 1000)
			end
		end
	end

	update_static_duration_value()

	local duration_value = iup.GetDialogChild(dlg, "DURATION")
	function duration_value:killfocus_cb()
		local duration = tonumber(self.VALUE)

		if sample_eid then
			local e = world[sample_eid]
			local anicomp = e.animation
			if anicomp then
				local anihandle = anicomp.assetinfo.handle
				local aniduration = anihandle:duration()
				local ratio = math.min(math.max(0, duration / aniduration), 1)
				anicomp.ratio = ratio
			end
		end
	end
	
	local function update_duration_text(cursorpos)		
		if duration_value == nil then
			return 
		end

		local sample_e = world[sample_eid]		
		if sample_e == nil then
			return nil
		end

		local anicomp = sample_e.animation
		if anicomp then
			local ani_assetinfo = anicomp.assetinfo
			if ani_assetinfo then
				local ani_handle = ani_assetinfo.handle
				local duration_pos = ani_handle:duration() * cursorpos
				duration_value.VALUE = string.format("%2f", duration_pos)
			end
		end
	end

	local function slider_value_chaged(slider)
		local cursorpos = get_ani_cursor(slider)
		update_duration_text(cursorpos)
		update_animation_ratio(sample_eid, cursorpos)
	end

	function slider:valuechanged_cb()
		slider_value_chaged(self)
	end

	slider_value_chaged(slider)

	iup.Map(dlg)
end

local function init_lighting()
	local lu = require "render.light.util"
	local leid = lu.create_directional_light_entity(world)
	local lentity = world[leid]
	local lightcomp = lentity.light
	lightcomp.color = {1,1,1,1}
	lightcomp.intensity = 2.0
	ms(lentity.rotation, {123.4, -34.22,-28.2}, "=")
end

local function focus_sample()
	if sample_eid then		
		world:change_component(sample_eid, "focus_selected_obj")
		world.notify()
	end
end

-- luacheck: ignore self
function model_ed_sys:init()	
	init_control()
	init_lighting()

	create_plane_entity()

	focus_sample()
end