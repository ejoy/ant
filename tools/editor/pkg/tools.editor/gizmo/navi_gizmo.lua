local ecs = ...
local world = ecs.world
local w     = world.w
local iom       = ecs.require "ant.objcontroller|obj_motion"
local ientity 	= ecs.require "ant.entity|entity"
local ipl 		= ecs.require "ant.polyline|polyline"
local ivm		= ecs.require "ant.render|visible_mask"
local queuemgr  = ecs.require "ant.render|queue_mgr"
local icamera	= ecs.require "ant.camera|camera"
local irender	= ecs.require "ant.render|render"
local iviewport = ecs.require "ant.render|viewport.state"
local gizmo 	= ecs.require "gizmo.gizmo"
local irq		= ecs.require "ant.render|renderqueue"
local renderpkg = import_package "ant.render"
local hwi       = import_package "ant.hwi"
local mathpkg	= import_package "ant.math"
local mc, mu	= mathpkg.constant, mathpkg.util
local math3d    = require "math3d"


local queuename = "navi_axis_queue"
-- local navi_axis_viewid = hwi.viewid_generate("navi_axis_queue", "main_view")
local fbmgr     = renderpkg.fbmgr
local navi_axis_view_size = 256
local m = {}
function m:hit_test(x, y)
	local navi_x = iviewport.device_viewrect.w - navi_axis_view_size
	if x < navi_x or x > iviewport.device_viewrect.w or y < 0 or y > navi_axis_view_size then
		return
	end
	
	local function dist_to(px1, py1, x2, y2)
		local px2 = (x2 + 1) * 0.5 * navi_axis_view_size
		local py2 = (y2 + 1) * 0.5 * navi_axis_view_size
		local dx = math.abs(px1 - px2)
		local dy = math.abs(py1 - py2)
		return math.sqrt(dx * dx + dy * dy)
	end
	local nx, ny = x - navi_x, navi_axis_view_size - y
	self.show_background = (dist_to(nx, ny, 0, 0) <= 90)
	for _, it in ipairs(self.sorted_draw) do
		it.active_eid = 1
	end
	for _, it in ipairs(self.sorted_draw) do
		if dist_to(nx, ny, it.tp[1], it.tp[2]) <= 20 then
			it.active_eid = 2
			return it.euler
		end
	end
end

local POLYLINE_MTL = "/pkg/tools.editor/resource/materials/polyline.material"
local function create_navi_obj(material, size, zvalue)
	local sz = size or 0.125
	local z = zvalue or 0
	local vbdata = {
        -sz, -sz, z, 0, 1,
        -sz,  sz, z, 0, 0,
         sz, -sz, z, 1, 1,
         sz,  sz, z, 1, 0,
    }
    return world:create_entity{
        policy = {
            "ant.render|simplerender",
        },
        data = {
            render_layer = "translucent",
            scene = {},
            visible = false,
            material = material,
            mesh_result = ientity.create_mesh{"p3|t2", vbdata},
        }
    }
end

function m:init()
    self.disable_main_view = true
    queuemgr.register_queue(queuename)
    RENDER_ARG = irender.pack_render_arg(queuename, hwi.viewid_generate(queuename, "main_view"))
    w:register{name = queuename}
end

function m:entity_init()
    local function on_ready(e)
		local eye, at = math3d.vector(0, 0, -3), mc.ZERO_PT
    	iom.set_position(e, eye)
    	iom.set_direction(e, math3d.normalize(math3d.sub(at, eye)))
	end
    for e in w:select "INIT main_queue render_target:in" do
		local navi_camera = icamera.create({
			name = "navi_camera",
			frustum = {
				l = -1, r = 1, t = 1, b = -1,
				n = 1, f = 100, ortho = true,
			},
			exposure = {
				type 			= "manual",
				aperture 		= 16.0,
				shutter_speed 	= 0.008,
				ISO 			= 100,
			}
		}, on_ready)
        local vr = iviewport.device_viewrect
        world:create_entity {
            policy = {
                "ant.render|render_queue",
            },
            data = {
                render_target       = {
                    viewid		        = hwi.viewid_get(queuename),
                    clear_state	        = {clear = ""},
                    view_rect	        = {
						x = vr.w - navi_axis_view_size,
						y = 0,
						w = navi_axis_view_size,
						h = navi_axis_view_size,
					},
                    fb_idx		        = fbmgr.get_fb_idx(hwi.viewid_get "main_view"),
                },
                camera_ref          = navi_camera,
                [queuename]	        = true,
                queue_name			= queuename,
                submit_queue		= true,
                visible 			= true,
            }
        }
    end
end

function m:create_navi_axis()
    local sorted_draw = {}
    self.navi_axis_background = create_navi_obj("/pkg/tools.editor/resource/materials/navi_background.material", 0.65, 1.0)
	sorted_draw[#sorted_draw + 1] = {tp = {0.5,0,0}, pos = math3d.ref(math3d.vector(0.5,0,0)), euler = {0, math.rad(-90), 0}, active_eid = 1,
		eid = {create_navi_obj("/pkg/tools.editor/resource/materials/navi_px.material"), create_navi_obj("/pkg/tools.editor/resource/materials/navi_hpx.material")}}
	sorted_draw[#sorted_draw + 1] = {tp = {-0.5,0,0}, pos = math3d.ref(math3d.vector(-0.5,0,0)), euler = {0, math.rad(90), 0}, active_eid = 1,
		eid = {create_navi_obj("/pkg/tools.editor/resource/materials/navi_nx.material"), create_navi_obj("/pkg/tools.editor/resource/materials/navi_hnx.material")}}
	sorted_draw[#sorted_draw + 1] = {tp = {0,0.5,0}, pos = math3d.ref(math3d.vector(0,0.5,0)), euler = {math.rad(89), 0, 0}, active_eid = 1,
		eid = {create_navi_obj("/pkg/tools.editor/resource/materials/navi_py.material"), create_navi_obj("/pkg/tools.editor/resource/materials/navi_hpy.material")}}
	sorted_draw[#sorted_draw + 1] = {tp = {0,-0.5,0}, pos = math3d.ref(math3d.vector(0,-0.5,0)), euler = {math.rad(-85), 0, 0}, active_eid = 1,
		eid = {create_navi_obj("/pkg/tools.editor/resource/materials/navi_ny.material"), create_navi_obj("/pkg/tools.editor/resource/materials/navi_hny.material")}}
	sorted_draw[#sorted_draw + 1] = {tp = {0,0,0.5}, pos = math3d.ref(math3d.vector(0,0,0.5)), euler = {0, math.rad(180), 0}, active_eid = 1,
		eid = {create_navi_obj("/pkg/tools.editor/resource/materials/navi_pz.material"), create_navi_obj("/pkg/tools.editor/resource/materials/navi_hpz.material")}}
	sorted_draw[#sorted_draw + 1] = {tp = {0,0,-0.5}, pos = math3d.ref(math3d.vector(0,0,-0.5)), euler = {0, 0, 0}, active_eid = 1,
		eid = {create_navi_obj("/pkg/tools.editor/resource/materials/navi_nz.material"), create_navi_obj("/pkg/tools.editor/resource/materials/navi_hnz.material")}}
	self.sorted_draw = sorted_draw

	local axis_parent = world:create_entity {
		policy = {
			"ant.scene|scene_object",
		},
		data = {
			scene = {},
		},
		tag = {
			"nav_axis root"
		}
	}
    local navi_axis = {}
	navi_axis[#navi_axis + 1] = axis_parent
	navi_axis[#navi_axis + 1] = ipl.add_strip_lines({{0, 0, 0},{0.5, 0, 0}}, 5, gizmo.tx.color, POLYLINE_MTL, false, {parent = axis_parent}, "translucent")
	navi_axis[#navi_axis + 1] = ipl.add_strip_lines({{0, 0, 0},{0, 0.5, 0}}, 5, gizmo.ty.color, POLYLINE_MTL, false, {parent = axis_parent}, "translucent")
	navi_axis[#navi_axis + 1] = ipl.add_strip_lines({{0, 0, 0},{0, 0, 0.5}}, 5, gizmo.tz.color, POLYLINE_MTL, false, {parent = axis_parent}, "translucent")
    self.navi_axis = navi_axis
end

local function on_click_navi_axis(euler)
	local mq = w:first("main_queue camera_ref:in")
	local ce <close> = world:entity(mq.camera_ref)
	iom.set_rotation(ce, math3d.quaternion(euler))
end

function m:on_click(x, y)
    local euler = self:hit_test(x, y)
    if euler then
        on_click_navi_axis(euler)
        return true
    end
end

function m:on_view_rect()
	local vr = iviewport.device_viewrect
	irq.set_view_rect(queuename, {
		x = vr.w - navi_axis_view_size,
		y = 0,
		w = navi_axis_view_size,
		h = navi_axis_view_size,
	})
end

function m:update()
    if self.disable_main_view then
        self.disable_main_view = false
		for i = 2, #self.navi_axis do
			local e <close> = world:entity(self.navi_axis[i], "visible_masks?update")
			ivm.set_masks(e, "main_view", false)
		end
		for _, v in ipairs(self.sorted_draw) do
			local e <close> = world:entity(v.eid[1], "visible_masks?update")
			ivm.set_masks(e, "main_view", false)
			local e1 <close> = world:entity(v.eid[2], "visible_masks?update")
			ivm.set_masks(e1, "main_view", false)
		end
	end
	local function update_worldmat(eid, pos)
		local e <close> = world:entity(eid, "scene:update render_object:update")
		local scene = e.scene
		math3d.unmark(scene.worldmat)
		scene.worldmat = math3d.mark(math3d.matrix{t = pos})
		e.render_object.worldmat = scene.worldmat
	end
	if w:check "scene_changed camera" then
        local mq = w:first("main_queue camera_ref:in")
        local ce <close> = world:entity(mq.camera_ref, "scene_changed?in camera:in scene:in")
        if ce.scene_changed then
			local re <close> = world:entity(self.navi_axis[1])
			local rotation = math3d.inverse(iom.get_rotation(ce))
			iom.set_rotation(re, rotation)

			for _, v in ipairs(self.sorted_draw) do
				local pos = math3d.transform(rotation, v.pos, 1)
				v.tp[1], v.tp[2], v.tp[3]= math3d.index(pos, 1), math3d.index(pos, 2), math3d.index(pos, 3)
				update_worldmat(v.eid[1], pos)
				update_worldmat(v.eid[2], pos)
			end
			table.sort(self.sorted_draw, function (a, b) return a.tp[3] > b.tp[3] end)
		end
	end
end

function m:draw()
    if self.show_background then
		irender.draw(RENDER_ARG, self.navi_axis_background)
	end
	for i = 2, #self.navi_axis do
		irender.draw(RENDER_ARG, self.navi_axis[i])
	end
	for _, v in ipairs(self.sorted_draw) do
		irender.draw(RENDER_ARG, v.eid[v.active_eid])
	end
end

return m